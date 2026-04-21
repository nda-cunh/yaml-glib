namespace Yaml {
	public class Node {
		private Variant? inner;

		public Node(Variant? v) {
			this.inner = v;
		}

		public Node get(string key) {
			if (inner == null)
				return new Node(null);

			Variant current = inner;
			if (current.classify() == Variant.Class.VARIANT) {
				current = current.get_variant();
			}

			if (current.get_type_string().has_prefix("a{")) {
				var val = current.lookup_value(key, null);
				return new Node(val);
			}

			return new Node(null);

		}

		public double as_double(double fallback = 0.0) {
			if (inner.is_of_type(VariantType.DOUBLE))
				return inner.get_double();
			else if (inner.is_of_type(VariantType.INT64))
				return (double)inner.get_int64();
			else if (inner.is_of_type(VariantType.STRING)) {
				double result;
				if (double.try_parse(inner.get_string(), out result))
					return result;
			}
			return fallback;
		}

		public bool as_bool(bool fallback = false) {
			if (inner.is_of_type(VariantType.BOOLEAN))
				return inner.get_boolean();
			else if (inner.is_of_type(VariantType.INT64))
				return (inner.get_int64() != 0);
			else if (inner.is_of_type(VariantType.STRING)) {
				var val = inner as string;
				if (val == "true" || val == "yes" || val == "on" || val == "1")
					return true;
				if (val == "false" || val == "no" || val == "off" || val == "0")
					return false;
			}
			return fallback;
		}

		public string as_string(string fallback = "") {
			if (inner.is_of_type(VariantType.INT32))
				return inner.get_string();
			else if (inner.is_of_type(VariantType.INT64))
				return inner.get_int64().to_string();
			else if (inner.is_of_type(VariantType.BOOLEAN))
				return inner.get_boolean().to_string();
			return fallback;
		}

		public string to_string () {
			return (inner != null) ? inner.print(true) : "null";
		}

		public bool contains (string key) {
			if (!is_dict()) return false;
			return inner.lookup_value(key, null) != null;
		}

		public bool has_key(string key) {
			if (!is_dict()) return false;
			return inner.lookup_value(key, null) != null;
		}

		public int as_int(int fallback = 0) {
			int64? s = inner as int64; 
			return (int)(s ?? fallback);
		}

		public bool is_null() {
			return inner == null;
		}

		public bool is_array() {
			return inner != null && (inner.classify() == Variant.Class.ARRAY && !inner.get_type_string().has_prefix("a{"));
		}

		public bool is_dict() {
			return inner != null && inner.get_type_string().has_prefix("a{");
		}

		public bool is_string() {
			return inner != null && inner.is_of_type(VariantType.STRING);
		}

		public int size() {
			if (inner == null) return 0;

			Variant current = inner;
			if (current.classify() == Variant.Class.VARIANT) {
				current = current.get_variant();
			}

			if (current.classify() == Variant.Class.ARRAY) {
				return (int)current.n_children();
			}
			return 0;
		}

		public Node at(int index) {
			if (inner == null) return new Node(null);

			Variant current = inner;
			if (current.classify() == Variant.Class.VARIANT) {
				current = current.get_variant();
			}

			if (current.classify() == Variant.Class.ARRAY) {
				if (index >= 0 && index < (int)current.n_children()) {
					var val = current.get_child_value(index);
					if (val.classify() == Variant.Class.VARIANT) {
						val = val.get_variant();
					}
					return new Node(val);
				}
			}
			return new Node(null);
		}

		public Iterator iterator() {
			return new Iterator(this);
		}

		public class Iterator {
			private int index = 0;
			private int size = 0;
			private Node node;

			public Iterator(Node node) {
				this.node = node;
				this.size = node.size();
			}

			public bool next() {
				return index < size;
			}

			public Node get() {
				var child = node.at(index);
				index++;
				return child;
			}
		}

	}
}
