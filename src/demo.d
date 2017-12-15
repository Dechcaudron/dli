import std.stdio;

import dli.helper_functions;
import dli.index_menu;
import dli.menu_items.simple_menu_item;
import dli.menu_items.nested_menu_menu_item;

import std.stdio;
import std.string;

void main()
{
	auto mainMenu = createIndexMenu();
	mainMenu.welcomeMsg = "Welcome to the demo menu. Please, choose an option below:";
	mainMenu.onMenuExitMsg = "We hope you enjoyed the demo!";

	mainMenu.addItem(
		createSimpleMenuItem(
			"Write \"Hello world!\"",
			{mainMenu.writeln("Hello world!");}
		)
	);

	mainMenu.addItem(
		createSimpleMenuItem(
			"Change item printing style to something fancy",
			{mainMenu.itemPrintFormat = "[" ~ mainMenu.printItemIdKeyword ~ "] => " ~ mainMenu.printItemTextKeyword;}
		)
	);

	mainMenu.addItem(
		createSimpleMenuItem(
			"Change item printing style to something simple",
			{mainMenu.itemPrintFormat = mainMenu.printItemIdKeyword ~ " - " ~ mainMenu.printItemTextKeyword;}
		)
	);

	auto uselessItem = createSimpleMenuItem("I do nothing", {});
	mainMenu.addItem(uselessItem);

	mainMenu.addItem(
		createSimpleMenuItem(
			"Toggle useless item",
			{uselessItem.enabled = !uselessItem.enabled;}
		)
	);

	// Show user input features
	{
		auto nestedMenu = createIndexMenu();
		nestedMenu.welcomeMsg = "Have a look at input support:";

		nestedMenu.addItem(
			createSimpleMenuItem(
				"Request a number",
				{
					float myFloat;
					while(!request!float("Please, input an number: ", &myFloat))
						nestedMenu.writeln("That is not a valid number.");

					nestedMenu.writeln(format("Thanks for your number %s.", myFloat));
				}
			)
		);

		nestedMenu.addItem(
			createSimpleMenuItem(
				"Request an even integer",
				{
					int myEvenInt;
					while(!request("Please, input an even integer: ", &myEvenInt, (int myInt){return myInt % 2 == 0;}))
						nestedMenu.writeln("That is not an even integer.");

					nestedMenu.writeln(format("Thanks for the even integer %s", myEvenInt));
				}
			)
		);

		nestedMenu.addItem(
			createSimpleMenuItem(
				"Request a character",
				{
					char myChar;
					while(!request!char("Please, input a character: ", &myChar))
						nestedMenu.writeln("That is not a character. Just press a key and then ENTER, please.");

					nestedMenu.writeln(format("Thanks for your character %s.", myChar));
				}
			)
		);

		mainMenu.addItem(
			new NestedMenuMenuItem(nestedMenu, "Open input demo nested menu")
		);
	}
	
	mainMenu.run();
}
