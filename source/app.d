import std.stdio;

import dli.index_menu;
import dli.menu_item;

import std.stdio;

void main()
{
	auto menu = makeIndexMenu();
	menu.welcomeMsg = "This is our menu:";
	menu.onMenuExitMsg = "Goodbye!";
	menu.itemPrintFormat = "[" ~ menu.printItemIdKeyword ~ "] " ~ menu.printItemTextKeyword;

	auto item1 = createMenuItem("Item 1", {writeln("Hello from item 1");});
	auto item2 = createMenuItem("Item 2", {writeln("Hello from item 2");});
	auto item3 = createMenuItem("Toggle item 2", {item2.enabled = !item2.enabled;});
	menu.addItem(item1, 1);
	menu.addItem(item2, 2);
	menu.addItem(item3, 3);

	menu.run();
}
