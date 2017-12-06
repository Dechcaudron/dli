module dli.menu;

public import dli.menu_items.simple_menu_item;
public import dli.display_scenario;
import dli.exceptions.invalid_item_exception;
import dli.exceptions.invalid_menu_status_exception;
import dli.exceptions.invalid_key_exception;
import dli.i_text_menu;

import std.exception;
import std.range.interfaces;
import std.range.primitives;
import std.typecons : Tuple, tuple;
import std.string : format;

public abstract class Menu(inputStreamT, outputStreamT, keyT) : ITextMenu
{
    protected inputStreamT inputStream;
    protected outputStreamT outputStream;

    protected MenuItem[keyT] menuItems;

    private string _welcomeMsg = "Please, select an option:"; // Welcome message for this menu
    private DisplayScenario _welcomeMsgDisplayScenario; // Scenario when the welcome message should be displayed

    private string _promptMsg = "> "; // String to be printed before asking the user for input
    private string _onItemExecutedMsg = "\n"; // String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private string _onMenuExitMsg = "Exiting menu...";
    private string _onInvalidItemSelectedMsg = "Please, select a valid item from the list.";

    public static enum printItemIdKeyword = "_$_ID_$_"; /// String to be used in place of the MenuItem identifier in itemPrintFormat
    public static enum printItemTextKeyword = "_$_TEXT_$_"; /// String to be used in place of the MenuItem text in itemPrintFormat
    private string _itemPrintFormat = printItemIdKeyword ~ " - " ~ printItemTextKeyword; /// Stores the format in which menu items are printed to the output stream

    private Status _status = Status.Stopped;

    @property
    protected Status status()
    {
        return _status;
    }

    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _welcomeMsg)));
    mixin(generateMenuCustomizingSetter!DisplayScenario(__traits(identifier, _welcomeMsgDisplayScenario)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _promptMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _onMenuExitMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _onInvalidItemSelectedMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _itemPrintFormat)));

    /// Removes the menu item associated with key. If no item was associated with such key, nothing happens.
    public void removeItem(keyT key)
    {
        enforce!InvalidMenuStatusException(status is Status.Stopped,
            "removeItem may not be called while the menu is running");

        menuItems.remove(key);
    }

    /// Removes all items from this menu.
    public void removeAllItems()
    {
        enforce!InvalidMenuStatusException(status is Status.Stopped,
            "removeAllItems may not be called while the menu is running.");

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
        enforce!InvalidMenuStatusException(status is Status.Stopped,
            "addItem may not be called while the menu is running");
        enforce!InvalidKeyException(key !in menuItems,
            format("Tried to call addItem with key %s, but it is already in use.", key));

        item.bind(this);
        menuItems[key] = item;
    }

    private void printEnabledItems()
    {
        import std.conv : to;

        void printItem(string key, string itemText)
        {
            import std.string : replace;

            string toBePrinted = _itemPrintFormat.replace(printItemIdKeyword, key).
                                replace(printItemTextKeyword, itemText);
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
        import std.conv : to, ConvException;

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
        
        menuItem.tryExecute();
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

    /// Starts the menu. This method can only be called if the menu is stopped.
    public override void run()
    {
        enforce!InvalidMenuStatusException(_status == Status.Stopped,
         "run may not be called while the menu is running.");

        try
        {
            _status = Status.Starting;
            /* Before actually starting the menu, we need to provide the user with a way to
               exit the menu. We create an ad hoc MenuItem for this purpose and add it here */
            addExitMenuItem(createSimpleMenuItem("Exit", 
                {
                    writeln(_onMenuExitMsg);
                    _status = Status.Stopping;}));

            _status = Status.Running;

            while(_status == Status.Running)
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
            _status = Status.Stopped;
        }
    }

    public override void writeln(string s)
    {
        outputStream.writeln(s);
    }

    public override void write(string s)
    {
        outputStream.write(s);
    }

    public override string readln()
    {
        return inputStream.readln();
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
        import std.conv : to;

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
public abstract class MenuItem
{
    /// Description of this item printed by the menu
    immutable string displayString;

    protected ITextMenu textMenu;
    private string confirmationRequestMsg;
    private string confirmationAnswer;

    private bool _enabled;

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
    this(string displayString, bool enabled)
    {
        this.displayString = displayString;
        this.enabled = enabled;
    }

    /**
        This method enables asking the user for confirmation prior to execution of the
        item after its selection.

        confirmationRequestMsg is the message displayed to the user when the item is selected.
        confirmationAnswer is the exact string (excluding line terminator and trailing whitespaces)
                           the user must input to execute the item.
    */
    public final void requireConfirmation(string confirmationRequestMsg, string confirmationAnswer)
    in
    {
        assert(confirmationRequestMsg !is null);
        assert(confirmationAnswer !is null);
    } 
    body
    {
        this.confirmationRequestMsg = confirmationRequestMsg;
        this.confirmationAnswer = confirmationAnswer;
    }

    protected abstract void execute();

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

    private void tryExecute()
    {
        bool requestConfirmation()
        {
            import std.string : strip;

            textMenu.write(confirmationRequestMsg);
            auto answer = textMenu.readln().strip();
            return answer == confirmationAnswer;
        }

        // Does this item require confirmation?
        if(confirmationRequestMsg is null || requestConfirmation())
            execute();
    }
}

// TESTS
version(unittest)
{
    import test.dli.mock_menu;
    import test.dli.mock_menu_item;

    @("Menu allows execution of items")
    unittest
    {
        auto menu = new MockMenu();
        auto item = new MockMenuItem();

        menu.addItem(item, 1);
        menu.mock_writeln("1");
        menu.mock_writeExitRequest();
        menu.run();

        assert(item.executed);
    }

    @("Menu does not allow items to be added or removed while running")
    unittest
    {
        import dli.menu_items.simple_menu_item : SimpleMenuItem;

        auto menu = new MockMenu();
        auto addItemItem = createSimpleMenuItem("", 
            {
                menu.addItem(new MockMenuItem(), 1);
            });
        auto removeItemItem = createSimpleMenuItem("",
            {
                menu.removeItem(1);
            });
        auto removeAllItemsItem = createSimpleMenuItem("",
            {
                menu.removeAllItems();
            });

        menu.addItem(addItemItem, 1);
        menu.addItem(removeItemItem, 2);
        menu.addItem(removeAllItemsItem, 3);

        menu.mock_writeln("1");
        assertThrown!InvalidMenuStatusException(menu.run());

        menu.mock_writeln("2");
        assertThrown!InvalidMenuStatusException(menu.run());

        menu.mock_writeln("3");
        assertThrown!InvalidMenuStatusException(menu.run());
    }

    @("Menu does not allow two items to be added with the same key")
    unittest
    {
        auto menu = new MockMenu();
        auto item1 = new MockMenuItem();
        auto item2 = new MockMenuItem();

        menu.addItem(item1, 1);
        
        assertThrown!InvalidKeyException(menu.addItem(item1, 1));
        assertThrown!InvalidKeyException(menu.addItem(item2, 1));
    }

    @("MenuItem cannot be added to a menu twice")
    unittest
    {
        import std.exception : assertThrown;
        import dli.exceptions.item_bound_exception : ItemBoundException;

        auto menu1 = new MockMenu();
        auto menu2 = new MockMenu();
        auto item = new MockMenuItem();

        menu1.addItem(item, 1); // item is now bound to menu1
        
        assertThrown!ItemBoundException(menu1.addItem(item, 2));
        assertThrown!ItemBoundException(menu2.addItem(item, 1));
    }

    @("MenuItem can require confirmation from user")
    unittest
    {
        auto menu = new MockMenu();
        auto item = new MockMenuItem();

        immutable string confirmationAnswer = "_CONFIRM_"; // Just a random string
        item.requireConfirmation("", confirmationAnswer);

        menu.addItem(item, 1);

        menu.mock_writeln("1");
        menu.mock_writeln("asdf"); // Whatever different from confirmationAnswer
        menu.mock_writeExitRequest();
        menu.run();

        assert(!item.executed);

        menu.mock_writeln("1");
        menu.mock_writeln(confirmationAnswer);
        menu.mock_writeExitRequest();
        menu.run();

        assert(item.executed);
    }
}