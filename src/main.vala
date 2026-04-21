using Yaml;

public void println(string format, ...) {
	va_list args = va_list();
	stdout.vprintf(format, args);
	stdout.printf("\n");
}

int main(string[] args) {
	Intl.setlocale();
	if (args.length < 2) {
		stderr.printf("Usage: %s <fichier.yaml>\n", args[0]);
		return 1;
	}

	try {
		string content;
		FileUtils.get_contents(args[1], out content);

		var parser = new Yaml.Parser();
		parser.parse(content);

		print ("----------------------------------\n");

		// print(parser.root_variant.print(true));

		var root = new Yaml.Node(parser.root_variant);
		var plugins = root["plugins"];

		println ("Yaml content :");

		println ("Theme: [%s]", root["settings"]["ui"]["theme"].as_string("default_theme"));
		println ("Font : [%d]", root["settings"]["ui"]["font_size"].as_int());
		println ("Plugins :");
		foreach (var plugin in plugins) {
			println (" Name   : [%s]", plugin["name"].as_string("no_name"));
			println (" Url    : [%s]", plugin["url"].as_string("not_defined"));
			println (" Active : [%s]", plugin["active"].as_string("false"));
			if (plugin["tags"].is_array()) {
				println ("  tags :");
				foreach (var tag in plugin["tags"]) {
					println ("    - %s", tag.as_string("inconnu"));
				}
			}
		}

	}
	catch (Error e) {
		stderr.printf("Erreur : %s\n", e.message);
		return 1;
	}

	return 0;
}
