module dli.menu_item;

public class MenuItem
{
    private string _text;
    private bool _enabled;

    @property public string text()
    {
        return _text;
    }

    @property public bool enabled()
    {
        return _enabled;
    }

    public this(string text, bool enabled = true)
    {
        _text = text;
        _enabled = enabled;
    }
}
