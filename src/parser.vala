using TreeSitter;

namespace Yaml {

	public class Parser : Object {
		[CCode (cname = "tree_sitter_yaml")]
			private extern static unowned Language tree_sitter_yaml ();

		public Variant? root_variant { get; private set; }

		public void parse(string source) {
			var ts_parser = new TreeSitter.Parser();
			ts_parser.set_language(tree_sitter_yaml());
			var tree = ts_parser.parse_string(null, source, source.length);
			var root_node = tree.get_root_node();

			this.root_variant = parse_node(root_node, source);
		}

		public Variant? lookup(string key, string? base_path = null) {
			if (this.root_variant == null) return null;

			string path = (base_path != null) ? base_path + "/" + key : key;

			return lookup_internal(this.root_variant, path);
		}

		private Variant? lookup_internal(Variant container, string path) {
			string[] parts = path.split("/");
			Variant? current = container;

			foreach (var part in parts) {
				if (part == "" || current == null) continue;

				if (current.is_of_type(new VariantType("a{sv}"))) {
					current = current.lookup_value(part, null);
					if (current != null && current.is_of_type(VariantType.VARIANT)) {
						current = current.get_variant();
					}
				}
				else if (current.is_of_type(new VariantType("av"))) {
					int index = (int) uint64.parse(part);
					if (index >= 0 && index < current.n_children()) {
						current = current.get_child_value(index);
						if (current.is_of_type(VariantType.VARIANT)) {
							current = current.get_variant();
						}
					} else return null;
				}
				else return null;
			}
			return current;
		}

		public Variant parse_node(TreeSitter.Node node, string source) {
			string type = node.get_type();

			if (type == "stream" || type == "document") {
				for (uint i = 0; i < TreeSitter.node_get_child_count(node); i++) {
					var child = TreeSitter.node_get_child(node, i);
					string c_type = child.get_type();

					if (c_type == "comment" || c_type == "-" || c_type == "...") continue;

					return parse_node(child, source);
				}
			}

			if (type == "block_node" || type == "flow_node") {
				for (uint i = 0; i < TreeSitter.node_get_child_count(node); i++) {
					var child = TreeSitter.node_get_child(node, i);
					if (child.get_type() == "comment") continue;
					return parse_node(child, source);
				}
			}

			switch (type) {
				case "block_mapping":
					var builder = new VariantBuilder(new VariantType("a{sv}"));
					for (uint i = 0; i < TreeSitter.node_get_child_count(node); i++) {
						var child = TreeSitter.node_get_child(node, i);
						var k_node = TreeSitter.node_get_child_by_field_name(child, "key", 3);
						var v_node = TreeSitter.node_get_child_by_field_name(child, "value", 5);

						if (!TreeSitter.node_is_null(k_node) && !TreeSitter.node_is_null(v_node)) {
							builder.add("{sv}",
									get_node_text(k_node, source),
									parse_node(v_node, source)
									);
						}
					}
					return builder.end();
				case "block_sequence":
					var builder = new VariantBuilder(new VariantType("av"));
					for (uint i = 0; i < TreeSitter.node_get_child_count(node); i++) {
						var item = TreeSitter.node_get_child(node, i);

						if (item.get_type() == "block_sequence_item") {
							for (uint j = 0; j < TreeSitter.node_get_child_count(item); j++) {
								var child = TreeSitter.node_get_child(item, j);
								if (child.get_type() != "-") {
									builder.add("v", parse_node(child, source));
									break; 
								}
							}
						}
					}
					return builder.end();

				case "flow_sequence":
					var builder = new VariantBuilder(new VariantType("av"));
					for (uint i = 0; i < TreeSitter.node_get_child_count(node); i++) {
						var item = TreeSitter.node_get_child(node, i);
						string itype = item.get_type();

						if (itype == "[" || itype == "]" || itype == ",") continue;

						builder.add("v", parse_node(item, source));
					}
					return builder.end();
				case "block_node":
				case "flow_node":
				case "document":
				case "stream":
					if (TreeSitter.node_get_child_count(node) > 0) {
						return parse_node(TreeSitter.node_get_child(node, 0), source);
					}
					return new Variant.string("");

				default:
					if (type == "comment") return new Variant.string("");

					string text = get_node_text(node, source);

					if (text.has_prefix("\"") && text.has_suffix("\"")) {
						return new Variant.string(text.substring(1, text.length - 2));
					}

					if (text.has_prefix("'") && text.has_suffix("'")) {
						return new Variant.string(text.substring(1, text.length - 2));
					}

					if (text == "true" || text == "false") {
						return new Variant.boolean(text == "true");
					}

					int64 val;
					if (int64.try_parse(text, out val)) {
						return new Variant.int64(val);
					}

					return new Variant.string(text);
			}
		}

		private string get_node_text(TreeSitter.Node node, string source) {
			return source.substring((int)node.get_start_byte(), (int)(node.get_end_byte() - node.get_start_byte())).strip();
		}

		public HashTable<string, string> to_hashmap(string source) {
			var map = new HashTable<string, string>(str_hash, str_equal);
			var ts_parser = new TreeSitter.Parser();
			ts_parser.set_language(tree_sitter_yaml());
			var tree = ts_parser.parse_string(null, source, source.length);
			var root = tree.get_root_node();

			string query_str = "(block_mapping_pair key: (_) @key value: (_) @value)";
			uint error_offset;
			QueryError error_type;
			var query = new Query(tree_sitter_yaml(), query_str, query_str.length, out error_offset, out error_type);

			var cursor = new QueryCursor();
			cursor.exec(query, root);

			QueryMatch match;
			while (cursor.next_match(out match)) {
				if (match.capture_count >= 2) {
					string key = get_node_text(match.captures[0].node, source);
					string val = get_node_text(match.captures[1].node, source);
					map.set(key, val);
				}
			}
			return map;
		}
	}
}

