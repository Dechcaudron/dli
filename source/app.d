import std.stdio;

import dli.index_menu;
import dli.menu_item;

import std.stdio;

void main()
{
	auto menu = makeIndexMenu();
	menu.setWelcomeMsg("This is our menu:");

	auto item1 = createMenuItem("Item 1", {writeln("Hello from item 1");});
	auto item2 = createMenuItem("Item 2", {writeln("Hello from item 2");});
	menu.addItem(item1, 1);
	menu.addItem(item2, 2);

	menu.run();
}
