using TreeSitter;

namespace Yaml {

	public class Parser : Object {
		[CCode (cname = "tree_sitter_yaml")]
		private extern static unowned Language tree_sitter_yaml ();

		public Variant? root_variant { get; private set; }

		public void parse (string source) throws ParseError {
			var ts_parser = new TreeSitter.Parser();
			ts_parser.set_language(tree_sitter_yaml());

			var tree = ts_parser.parse_string(null, source, source.length);
			var root_node = tree.get_root_node();

			if (root_node.has_error()) {
				throw new ParseError.INVALID_SYNTAX("Syntax error detected in YAML content.");
			}

			this.root_variant = parse_node(root_node, source);

			if (this.root_variant == null) {
				throw new ParseError.EMPTY_DOCUMENT("The YAML document is empty or could not be parsed.");
			}
		}

		public Variant? lookup (string key, string? base_path = null) {
			if (this.root_variant == null) return null;

			string path = (base_path != null) ? base_path + "/" + key : key;

			return lookup_internal(this.root_variant, path);
		}

		private Variant? lookup_internal (Variant container, string path) {
			string[] parts = path.split("/");
			Variant? current = container;

			foreach (unowned var part in parts) {
				if (part == "" || current == null) continue;

				if (current.get_type_string() == "a{sv}") {
					current = current.lookup_value(part, null);
					if (current != null && current.is_of_type(VariantType.VARIANT)) {
						current = current.get_variant();
					}
				}
				else if (current.classify() == Variant.Class.ARRAY) {
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

		public Variant parse_node (TreeSitter.Node node, string source) throws ParseError {
			unowned string type = node.get_type();
			if (node.is_error()) { // ou node.get_type() == "ERROR"
				var start = node.get_start_point();
				throw new ParseError.INVALID_SYNTAX ("Syntax error at line %u, column %u: near '%s'", start.row + 1, start.column + 1, get_node_text(node, source));
			}

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
				case "flow_mapping":
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

				case "block_scalar":
					return new Variant.string(get_node_text(node, source).substring(1)._strip());
				case "comment":
					return new Variant.string("");
				case "string":
				case "escape_sequence":	
				case "plain_scalar":				
				case "double_quote_scalar":
				case "single_quote_scalar":
					string text = get_node_text(node, source);
					return from_text(text);
				default:
					if (node.get_child_count() > 0) {
						throw new ParseError.UNEXPECTED_NODE("Unexpected node type '%s' with children at line %u, column %u", type, node.get_start_point().row + 1, node.get_start_point().column + 1);
					}
					string text = get_node_text(node, source);
					return from_text(text);
			}
		}

		private Variant from_text (string text) {
			if (text.has_prefix("\"") && text.has_suffix("\"")) {
				if (text.length >= 2)
					return new Variant.string(text.substring(1, text.length - 2));
			}

			if (text.has_prefix("'") && text.has_suffix("'")) {
				if (text.length >= 2)
					return new Variant.string(text.substring(1, text.length - 2));
			}

			if (text == "true" || text == "false") {
				return new Variant.boolean(text == "true");
			}

			if ("." in text) {
				double dval;
				if (double.try_parse(text, out dval)) {
					return new Variant.double(dval);
				}
			}

			int64 val;
			if (int64.try_parse(text, out val)) {
				return new Variant.int64(val);
			}
			return new Variant.string(text);
		}

		private string get_node_text(TreeSitter.Node node, string source) {
			return source.substring((int)node.get_start_byte(), (int)(node.get_end_byte() - node.get_start_byte()))._strip();
		}
	}
}
