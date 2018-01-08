# dli
**dli** is a command line interface library (I hope you appreciate the pun) for the D programming language. Although its main application
lies in easing the fast development of cli apps, it can also be used in not-only-cli apps, such as in an embedded console in a GUI app.

This software is licensed under the [MIT](https://opensource.org/licenses/MIT) software license.

# Why?
Because I hate handling user input every single time I need to ask for data, in every single app
I write. 

# Highlighted features
- Safely and easily request data from your user with the templated `request` method:
```d
    /* This code will keep asking for data until an integer
       number that fits in an `int` and satisfies the given
       condition is given */
    import dli;

    int myEvenInt;
	while(!request("Please, input an even integer: ", &myEvenInt,
                   (int myInt){return myInt % 2 == 0;})) // This argument is optional!
        writeln("That is not an even integer.");
```
The library also optionally supports the evaluation of math expressions for numeric types. So, if
you ask for an `int`, `128 * 5 / 2` is a perfectly valid input. The wiki contains more information
regarding math expression support.
- Easily create and run key-based menus:
```d
    import dli;

    auto mainMenu = createIndexMenu();
    mainMenu.welcomeMsg = "Please choose an option below:";

	mainMenu.addItem(
		new MenuItem(
			"Write \"Hello world!\"",  // Title of the item
			{writeln("Hello world!");} // This gets called when the item is selected
		)
	);

    ... add more items ...

    mainMenu.run();
```
will output something like:
```
Please choose an option below:
1 - Write "Hello world!"
... your items printed here ...
5 - Exit // This item is added automatically
> // Here you expect the user input
```
Don't worry about your user writing garbage to your menu's input. If the input cannot be matched to
an item, a warning message (customizable) will be printed, and the menu shown again.

These are just the main things the library can do. Head over to the [wiki](https://github.com/Dechcaudron/dli/wiki) and check out the
documentation to learn how to make the most out of it.

# Attributions
The following pieces of work make this library possible:
- [unit-threaded](https://github.com/atilaneves/unit-threaded), by *Atila Neves*, released under the [BSD-3-Clause](https://opensource.org/licenses/BSD-3-Clause) license. Used for the testing of the library.
- [ArithEval](https://github.com/Dechcaudron/ArithEval), by *Dechcaudron*, released under the [MIT](https://opensource.org/licenses/MIT) license. Used for optional support of math expressions as user input.