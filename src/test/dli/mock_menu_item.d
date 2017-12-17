module test.dli.mock_menu_item;

import dli.text_menu : MenuItem;

///
public class MockMenuItem : MenuItem
{
    private bool _executed;

    /// Whether the item has been executed or not.
    @property
    public bool executed() const
    {
        return _executed;
    }

    ///
    this(string displayString = "mockMenuItem", bool enabled = true)
    {
        super(displayString, {_executed = true;}, enabled);
    }
}