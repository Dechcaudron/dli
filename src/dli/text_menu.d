module dli.text_menu;

public import dli.display_scenario;
import dli.exceptions.invalid_item_exception;
import dli.exceptions.invalid_menu_status_exception;
import dli.exceptions.invalid_key_exception;
import dli.exceptions.no_menu_running_exception;
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

    private string _welcomeMsg = "Please, select an option:"; // Welcome message for this menu
    private DisplayScenario _welcomeMsgDisplayScenario; // Scenario when the welcome message should be displayed

    private string _promptMsg = "> "; // String to be printed before asking the user for input
    private string _onItemExecutedMsg = "\n"; // String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private void delegate() _onStart; /// Delegate to be called when the menu starts running;
    private void delegate() _onExit; /// Delegate to be called when the menu exits
    private string _onInvalidItemSelectedMsg = "Please, select a valid item from the list.";
    private string _itemPrintFormat = PrintItemKeyKeyword ~ " - " ~ PrintItemTextKeyword; /// Stores the format in which menu items are printed to the output stream
    private Status _status = Status.Stopped;

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
    body
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
            addExitMenuItem(new MenuItem("Exit", 
                {
                    _status = Status.Stopping;
                }
            ));

            _status = Status.Running;

            while (_status == Status.Running)
            {
                printWelcomeMsg();
                printEnabledItems();
                write(_promptMsg);
                try
                {
                    awaitAndExecuteUserInteraction();
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
    }

    protected this(textMenuT)(textMenuT streamSource)
    {
        this.inputStream = streamSource.inputStream;
        this.outputStream = streamSource.outputStream;
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

    private void awaitAndExecuteUserInteraction()
    {
        import std.string : strip;
        import std.format : format;

        // Note that we are calling strip here to remove the EOL chars, but at some point we may want to allow
        // someone to type leading or trailing whitespaces which they don't want removed. This will do for now.
        string cleansedUserInput = readln().strip();
        keyT menuItemKey;
        try
        {
            menuItemKey = to!keyT(cleansedUserInput);
        }
        catch(ConvException e)
        {
            // TODO: throw an InvalidInputException?
            throw new InvalidItemException(format!("Cannot convert user input '%s' " ~
                "into key type %s")(cleansedUserInput, keyT.stringof));
        }
        
        MenuItem menuItem = getMenuItem(menuItemKey);
        enforce!InvalidItemException(menuItem.enabled, format!("User tried to select disabled " ~
                "menu item with key %s")(menuItemKey));
        
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
    body
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
    body
    {
        import dli.exceptions.item_bound_exception : ItemBoundException;
        import std.string : format;

        enforce!ItemBoundException(this.textMenu is null, format("Cannot bind MenuItem %s to %s. It is already bound to %s",
                                                        this, textMenu, this.textMenu));

        this.textMenu = textMenu;
    }
}

// TESTS
version(unittest)
{
    import dli.input_string_stream;
    import dli.output_string_stream;

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

        menu.onStart = {onStartCallbackExecuted = true;};
        menu.onExit = {onExitCallbackExecuted = true;};
        
        // TODO: check in the middle of menu execution that onStart
        // has executed and onExit has not

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

    @("MenuItem cannot be added to a menu twice")
    unittest
    {
        import std.exception : assertThrown;
        import dli.exceptions.item_bound_exception : ItemBoundException;

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