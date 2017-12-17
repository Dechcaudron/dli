module test.dli.mock_menu;

import dli.text_menu;
import dli.input_string_stream;
import dli.output_string_stream;

///
public class MockMenu : TextMenu!(shared InputStringStream, shared OutputStringStream, size_t)
{
    private enum size_t exitMenuItemKey = size_t.max;

    /// Creates a MockMenu with its own input and output streams
    this()
    {
        super(new shared InputStringStream(), new shared OutputStringStream());
    }

    /// Creates a MockMenu that uses the input and output streams of the passed menu
    this(MockMenu mockMenu)
    {
        super(mockMenu);
    }

    /// Mocks the writing of a line into the input stream
    public void mock_writeln(string s)
    in
    {
        assert(s !is null);
    }
    body
    {
        inputStream.appendLine(s);
    }

    /// Mocks the required writing to select the "exit menu" menu item
    public void mock_writeExitRequest()
    {
        import std.conv : to;

        inputStream.appendLine(to!string(exitMenuItemKey));
    }

    protected override void addExitMenuItem(MenuItem exitMenuItem)
    {
        menuItems[exitMenuItemKey] = exitMenuItem;
    }

    protected override void removeExitMenuItem()
    {
        menuItems.remove(exitMenuItemKey);
    }
}