module dli.index_menu;

import dli.menu;
public import dli.menu_item;

import std.typecons;

private alias indexT = int;

public class IndexMenu(inputRangeT, outputRangeT) : Menu!(inputRangeT, outputRangeT)
{
    private MenuItem[] menuItems; /// Associative array of menu items

    public this(inputRangeT inRange, outputRangeT outRange)
    {
        inputRange = inRange;
        outputRange = outRange;
    }

    public this(Menu!(inputRangeT, outputRangeT) menu)
    {
        inputRange = menu.inputRange;
        outputRange = menu.outputRange;
    }

    public void addMenuItem(MenuItem item)
    in
    {
        assert(item !is null);
    }
    body
    {
        menuItems ~= item;
    }

    public void removeAllItems()
    {
        menuItems = [];
    }
}
