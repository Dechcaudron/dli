import dli;

import std.string;

void main()
{
	auto mainMenu = createIndexMenu();
	mainMenu.welcomeMsg = "Welcome to the demo menu. Please, choose an option below:";
	mainMenu.onExit = {writeln("We hope you enjoyed the demo!");};

	mainMenu.addItem(
		new MenuItem(
			"Write \"Hello world!\"",
			{writeln("Hello world!");}
		)
	);

	mainMenu.addItem(
		new MenuItem(
			"Change item printing style to something fancy",
			{mainMenu.itemPrintFormat = "[%item_key%] => %item_text%";}
		)
	);

	mainMenu.addItem(
		new MenuItem(
			"Change item printing style to something simple",
			{mainMenu.itemPrintFormat = "%item_key% - %item_text%";}
		)
	);

	auto uselessItem = new MenuItem("I do nothing", {});
	mainMenu.addItem(uselessItem);

	mainMenu.addItem(
		new MenuItem(
			"Toggle useless item",
			{uselessItem.enabled = !uselessItem.enabled;}
		)
	);

	// Show user input features
	{
		auto nestedMenu = createIndexMenu();
		nestedMenu.welcomeMsg = "Have a look at input support:";

		nestedMenu.addItem(
			new MenuItem(
				"Request a number",
				{
					float myFloat;
					while(!request("Please, input an number: ", &myFloat))
						writeln("That is not a valid number.");

					writeln(format("Thanks for your number %s.", myFloat));
				}
			)
		);

		nestedMenu.addItem(
			new MenuItem(
				"Request an even integer",
				{
					int myEvenInt;
					while(!request("Please, input an even integer: ", &myEvenInt,
						  (int myInt){return myInt % 2 == 0;}))
						writeln("That is not an even integer.");

					writeln(format("Thanks for the even integer %s", myEvenInt));
				}
			)
		);

		nestedMenu.addItem(
			new MenuItem(
				"Request a character",
				{
					dchar myChar;
					while(!request("Please, input a character: ", &myChar))
						writeln("That is not a character. Just press a key and then ENTER, please.");

					writeln(format("Thanks for your character %s.", myChar));
				}
			)
		);

		mainMenu.addItem(
			new NestedMenuMenuItem(nestedMenu, "Open input demo nested menu")
		);
	}
	
	mainMenu.run();
}
