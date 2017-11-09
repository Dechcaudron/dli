import std.stdio;

import dli.index_menu;

void main()
{
	auto menu = new IndexMenu();
	menu.setWelcomeMsg("This is our menu:");

	auto item1 = new MenuItem("Item 1");
	auto item2 = new MenuItem("Item 2");
	menu.addItem(item1, 1);
	menu.addItem(item2, 2);

	menu.run();
}
