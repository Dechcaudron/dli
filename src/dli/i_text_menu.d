module dli.i_text_menu;

///
public interface ITextMenu
{
    /// Runs the menu
    void run();

    /// Writes the argument to the output of the menu
    void write(string s)
    in
    {
        assert(s !is null);
    }

    /// Writes the argument plus a line terminator to the output of the menu
    void writeln(string s)
    in
    {
        assert(s !is null);
    }

    /// Reads a line from the input of the menu
    string readln()
    out(s)
    {
        assert(s !is null);
    }
}