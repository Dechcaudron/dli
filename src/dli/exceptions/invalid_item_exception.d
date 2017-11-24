module dli.exceptions.invalid_item_exception;

public class InvalidItemException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, null);
    }
}