///
module dli.text_menu;

import dli.display_scenario;
import dli.exceptions;
import dli.io : request;
import dli.i_text_menu;
import dli.internal.lifo;

import std.exception;
import std.range.interfaces;
import std.range.primitives;
import std.typecons : Tuple, tuple;
import std.string : format;
import std.conv;

package static Lifo!ITextMenu runningMenusStack;
package static ITextMenu activeTextMenu()
{
    return !runningMenusStack.empty ? runningMenusStack.front :
                                      null;
}

private enum PrintItemKeyKeyword = "%item_key%"; /// String to be used in place of the MenuItem identifier in itemPrintFormat
private enum PrintItemTextKeyword = "%item_text%"; /// String to be used in place of the MenuItem text in itemPrintFormat

///
public abstract class TextMenu(inputStreamT, outputStreamT, keyT) : ITextMenu
{
    protected inputStreamT inputStream;
    protected outputStreamT outputStream;

    protected MenuItem[keyT] menuItems;

    protected string _exitItemText = "Exit";

    private string _welcomeMsg = "Please, select an option:"; /// Welcome message for this menu
    private DisplayScenario _welcomeMsgDisplayScenario; /// Scenario when the welcome message should be displayed

    private string _promptMsg = "> "; /// String to be printed before asking the user for input
    private string _onItemExecutedMsg = "\n"; /// String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private void delegate() _onStart; /// Delegate to be called when the menu starts running;
    private void delegate() _onExit; /// Delegate to be called when the menu exits
    private string _onInvalidItemSelectedMsg = "Please, select a valid item from the list.";
    private string _itemPrintFormat = PrintItemKeyKeyword ~ " - " ~ PrintItemTextKeyword; /// Stores the format in which menu items are printed to the output stream
    private Status _status = Status.Stopped;
	private MenuItem exitMenuItem; 

    @property
    protected Status status()
    {
        return _status;
    }

    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _welcomeMsg)));
    mixin(generateMenuCustomizingSetter!DisplayScenario(__traits(identifier, _welcomeMsgDisplayScenario)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _promptMsg)));
    mixin(generateMenuCustomizingSetter!(void delegate())(__traits(identifier, _onStart)));
    mixin(generateMenuCustomizingSetter!(void delegate())(__traits(identifier, _onExit)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _onInvalidItemSelectedMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _itemPrintFormat)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _exitItemText)));

    /// Removes the menu item associated with key. If no item was associated with such key, nothing happens.
    public final void removeItem(keyT key)
    {
        menuItems.remove(key);
    }

    /// Removes all items from this menu.
    public final void removeAllItems()
    {
        menuItems.clear();
    }

    /// Associates the given item with the given key in this menu.
    public void addItem(MenuItem item, keyT key)
    in
    {
        assert(item !is null);
    }
    do
    {
        enforce!InvalidKeyException(key !in menuItems,
            format("Tried to call addItem with key %s, but it is already in use.", key));

        item.bind(this);
        menuItems[key] = item;
    }

    /** Starts the menu.

        Throws: InvalidMenuStatusException if the menu was not stopped prior
                to calling this method.
    */
    public override final void run()
    {
        enforce!InvalidMenuStatusException(_status == Status.Stopped,
         "run may not be called while the menu is running.");

        try
        {
            _status = Status.Starting;

            if (_onStart !is null)
                _onStart();

            runningMenusStack.put(this);

            /* Before actually starting the menu, we need to provide the user with a way to
               exit the menu. We create an ad hoc MenuItem for this purpose and add it here */
            addExitMenuItem(exitMenuItem);

            _status = Status.Running;

            while (_status == Status.Running)
            {
                printWelcomeMsg();
                printEnabledItems();
                try
                {
                    keyT selectedItemKey;
                    if(request(_promptMsg, &selectedItemKey))
                        tryExecuteItem(selectedItemKey);
                    else
                        throw new InvalidItemException("The user input was not convertible to a key.");
                }
                catch(InvalidItemException e)
                {
                    outputStream.writeln(_onInvalidItemSelectedMsg);
                }
                write(_onItemExecutedMsg);
            }
        }
        finally
        {
            _status = Status.Stopping;
            // In order to leave things as they were prior to calling this method, the ad hoc MenuItem used to exit the menu is removed
            removeExitMenuItem();
            if (_onExit !is null)
                _onExit();

            runningMenusStack.pop();
            _status = Status.Stopped;
        }
    }

	/// Set the text of the menu item that will make it possible to exit this menu instance.
	public void exitMenuItemDisplayString(string displayString)
	in
	{
		// Aside from internal implementation details, it does not sound like a good idea
		// to change the display string of an item while the menu is running, since it is bound
		// to confuse the user.
		assert(_status == Status.Stopped);
	}
	do
	{
		exitMenuItem = new MenuItem(displayString, {_status = Status.Stopping;});
	}

	/// Enables/disabled the menu item to leave this `TextMenu` instance.
	public void exitMenuItemEnabled(bool enabled)
	{
		exitMenuItem.enabled = enabled;
	}

    public override final void writeln(string s)
    {
        outputStream.writeln(s);
    }

    public override final void write(string s)
    {
        outputStream.write(s);
    }

    public override final string readln()
    {
        return inputStream.readln();
    }

    protected this(inputStreamT inputStream, outputStreamT outputStream)
    {
        this.inputStream = inputStream;
        this.outputStream = outputStream;   
		initializeExitMenuItem();
    }

    protected this(textMenuT)(textMenuT streamSource)
    {
        this.inputStream = streamSource.inputStream;
        this.outputStream = streamSource.outputStream;
		initializeExitMenuItem();
    }

	private void initializeExitMenuItem()
	{
		exitMenuItemDisplayString = "Exit";
	}

    private void printEnabledItems()
    {
        void printItem(string key, string itemText)
        {
            import std.string : replace;

            string toBePrinted = _itemPrintFormat.replace(PrintItemKeyKeyword, key).
                                replace(PrintItemTextKeyword, itemText);
            outputStream.writeln(toBePrinted);
        }

        foreach(Tuple!(keyT, MenuItem) itemTuple; sortItemsForDisplay())
            if(itemTuple[1].enabled)
                printItem(to!string(itemTuple[0]), itemTuple[1].displayString);
    }

    private void tryExecuteItem(keyT key)
    {
        MenuItem menuItem = getMenuItem(key);
        enforce!InvalidItemException(menuItem.enabled, format!("User tried to select disabled " ~
                "menu item with key %s")(key));
        
        menuItem.execute();
    }

    private void printWelcomeMsg()
    {
        outputStream.writeln(_welcomeMsg);
    }

    // TODO is this useful?
    protected final MenuItem getMenuItem(keyT key)
    {
        import std.format : format;
        enforce!InvalidItemException(key in menuItems, format!("Tried to retrieve " ~
                "unexisting menu item with key %s")(key));

        return menuItems[key];
    }

    protected Tuple!(keyT, MenuItem)[] sortItemsForDisplay()
    {
        //Default implementation simply returns the items as they are found in menuItems
        Tuple!(keyT, MenuItem)[] sortedItems;

        foreach(keyT key, MenuItem item; menuItems)
            sortedItems ~= tuple(key, item);

        return sortedItems;
    }

    abstract protected void addExitMenuItem(MenuItem exitMenuItem);
    abstract protected void removeExitMenuItem();

    protected enum Status
    {
        Stopping,
        Stopped,
        Starting,
        Running
    }

    // Helper function to generate setters via mixins
    private static string generateMenuCustomizingSetter(T)(string fieldName) pure
    in
    {
        assert(fieldName[0] == '_');
    }
    do
    {
        import std.uni : toUpper;

        string propertyIdentifier = fieldName[1..$];

        return format("@property
                    public void %s(%s a)
                    body
                    {
                        %s = a;
                    }", propertyIdentifier, T.stringof, fieldName);
    }
}


///
public class MenuItem
{
    /// Description of this item printed by the menu
    immutable string displayString;

    protected ITextMenu textMenu;
    private bool _enabled;
    private void delegate() action;

    /// Whether this item is enabled or not.
    @property
    public bool enabled() const
    {
        return _enabled;
    }

    /// Allows for enabling or disabling this item
    @property
    public void enabled(bool enable)
    {
        _enabled = enable;
    }

    ///
    this(string displayString, void delegate() action, bool enabled = true)
    in
    {
        assert(displayString !is null);
        assert(action !is null);
    }
    do
    {
        this.displayString = displayString;
        this.action = action;
        this.enabled = enabled;
    }

    ///
    this(string displayString, void function() action, bool enabled = true)
    in
    {
        assert(displayString !is null);
        assert(action !is null);
    }
    do
    {
        this(displayString, {action();}, enabled);
    }

    private void execute()
    {
        action();
    }

    /**
        Binds this MenuItem to a specific ITextMenu. This method may be only
        be called once.
    */
    private void bind(ITextMenu textMenu)
    in
    {
        assert(textMenu !is null);
    }
    do
    {
        enforce!ItemBoundException(this.textMenu is null, 
                                   format("Cannot bind MenuItem %s to %s. It is already bound to %s",
                                   this, textMenu, this.textMenu));

        this.textMenu = textMenu;
    }
}

// TESTS
version(unittest)
{
    import dli.string_stream.input_string_stream;
    import dli.string_stream.output_string_stream;

    private class TextMenuTestImplementation : TextMenu!(shared InputStringStream, shared OutputStringStream, int)
    {
        private enum int exitItemKey = -1;

        this(shared InputStringStream inputStream = new shared InputStringStream(), 
             shared OutputStringStream outputStream = new shared OutputStringStream())
        {
            super(inputStream, outputStream);
        }

        override void addItem(MenuItem item, int key)
        {
            if (status == Status.Stopped)
            {
                enforce(key != exitItemKey, 
                        "Tried to add an item with key associated to " ~
                        "the exit item in the test implementation"
                       );
            }
            else
            {
                enforce(status == Status.Starting);
                enforce(key == exitItemKey);
            }

            super.addItem(item, key);
        }

        override void addExitMenuItem(MenuItem item)
        {
            addItem(item, exitItemKey);
        }

        override void removeExitMenuItem()
        {
            removeItem(exitItemKey);
        }
    }

    @("TextMenu calls onStart and onExit callbacks")
    unittest
    {
        auto inputStream = new shared InputStringStream();
        auto menu = new TextMenuTestImplementation(inputStream);
        bool onStartCallbackExecuted;
        bool onExitCallbackExecuted;

        menu.onStart = {
            onStartCallbackExecuted = true; 
            assert(!onExitCallbackExecuted);
        };
        menu.onExit = {onExitCallbackExecuted = true;};
        
        inputStream.appendLine(to!string(TextMenuTestImplementation.exitItemKey));
        menu.run();

        assert(onStartCallbackExecuted);
        assert(onExitCallbackExecuted);
    }

    @("TextMenu does not allow two items to be added with the same key")
    unittest
    {
        auto menu = new TextMenuTestImplementation();
        auto item1 = new MenuItem("", {});
        auto item2 = new MenuItem("", {});

        menu.addItem(item1, 1);
        
        assertThrown!InvalidKeyException(menu.addItem(item1, 1));
        assertThrown!InvalidKeyException(menu.addItem(item2, 1));
    }

    @("TextMenu does not crash if EOF is reached when asking for item key")
    unittest
    {
        auto inputStream = new shared InputStringStream();
        auto menu = new TextMenuTestImplementation(inputStream);

        inputStream.append("" ~ eof);
        inputStream.appendLine("-1");
        menu.run();
    }

    @("MenuItem cannot be added to a menu twice")
    unittest
    {
        import std.exception : assertThrown;

        auto menu1 = new TextMenuTestImplementation();
        auto menu2 = new TextMenuTestImplementation();
        auto item = new MenuItem("",{});

        menu1.addItem(item, 1); // item is now bound to menu1
        
        assertThrown!ItemBoundException(menu1.addItem(item, 2));
        assertThrown!ItemBoundException(menu2.addItem(item, 1));
    }

    @("MenuItem calls actions when selected by the user in a TextMenu")
    unittest
    {
        auto inputStream = new shared InputStringStream();
        auto menu = new TextMenuTestImplementation(inputStream);
        bool actionCalled;
        void foo()
        {
            actionCalled = true;
        }
        auto item = new MenuItem("", &foo);

        menu.addItem(item, 1);
        inputStream.appendLine("1");
        inputStream.appendLine(to!string(TextMenuTestImplementation.exitItemKey));
        menu.run();

        assert(actionCalled);
    }
}
