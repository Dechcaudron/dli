module dli.index_menu;

import std.stdio;
import std.exception;
import std.conv;

import dli.menu;
import dli.exceptions.invalid_item_exception;
public import dli.menu_item;

import std.typecons;

public alias IndexMenu = CustomIndexMenu!(File, File);

public class CustomIndexMenu(inputStreamT, outputStreamT) : Menu!(inputStreamT, outputStreamT)
{
    private MenuItem[size_t] menuItems; // Associative array of menu items

    //static if(inputStreamT is File && outputStreamT is File)
        public this()
        {
            this(stdin, stdout);   
        }

    public this(inputStreamT inStream, outputStreamT outStream)
    {
        inputStream = inStream;
        outputStream = outStream;
    }

    public void addItem(MenuItem item, size_t itemIndex)
    in
    {
        assert(item !is null);
    }
    body
    {
        enforce(itemIndex !in menuItems);

        menuItems[itemIndex] = item;
    }

    public void removeAllItems()
    {
        menuItems.clear();
    }

    protected override void printItems()
    {
        // It is important that the items are printed in the correct order
        import std.algorithm.sorting;
        auto sortedKeys = sort(menuItems.keys);

        foreach(size_t menuItemIndex; sortedKeys)
        {
            auto item = menuItems[menuItemIndex];
            if(item.enabled)
                outputStream.writefln("%s - %s", menuItemIndex, item.text);
        }
    }

    protected override void parseUserSelection(string input)
    in
    {
        assert(input !is null);
    }
    body
    {
        size_t chosenItemIndex = to!size_t(input);

        enforce!InvalidItemException(chosenItemIndex in menuItems &&
                menuItems[chosenItemIndex].enabled);

        writefln("You chose item %s", chosenItemIndex);
    }
}
