module dli.menu_items.nested_menu_menu_item;

import dli.text_menu : MenuItem;
import dli.i_text_menu;

/// Shortcut class to ease nesting menus
public class NestedMenuMenuItem : MenuItem
{
    /// Create a new MenuItem that will run nestedMenu when executed
    public this(ITextMenu nestedMenu, string displayString, bool enabled = true)
    in
    {
        assert(nestedMenu !is null);
        assert(displayString !is null);
    }
    do
    {
        super(displayString, {nestedMenu.run();}, enabled);
    }
}

// TESTS
version(unittest)
{
    import test.dli.mock_menu;
    import test.dli.mock_menu_item;

    @("Test NestedMenuMenuItem properly stops and starts nested menus")
    unittest
    {
        auto parentMenu = new MockMenu();
        /*
            We employ this constructor here so that
            nestedMenu uses parentMenu's input and 
            output streams.
        */
        auto nestedMenu = new MockMenu(parentMenu);
        auto nestedMenuMenuItem = new NestedMenuMenuItem(nestedMenu, "");
        auto itemInNestedMenu = new MockMenuItem();

        parentMenu.addItem(nestedMenuMenuItem, 1);
        nestedMenu.addItem(itemInNestedMenu, 1);

        // First, enter the nested menu and exit it, without selecting the inner item
        parentMenu.mock_writeln("1");
        parentMenu.mock_writeExitRequest(); // This should exit the nested menu
        parentMenu.mock_writeExitRequest(); // This should the parent menu
        parentMenu.run();

        assert(!itemInNestedMenu.executed);

        // Now try to execute it
        parentMenu.mock_writeln("1");
        parentMenu.mock_writeln("1");
        parentMenu.mock_writeExitRequest(); 
        parentMenu.mock_writeExitRequest();
        parentMenu.run();

        assert(itemInNestedMenu.executed);
    }
}