module dli.output_string_stream;

public shared class OutputStringStream
{
    private string _content = "";
    immutable string lineTerminator;

    @property
    public string content()
    out(s)
    {
        assert(s !is null);
    }
    body
    {
        return _content;
    }

    public this(string content = "", string lineTerminator = "\n")
    in
    {
        assert(content !is null);
        assert(lineTerminator !is null);
    }
    body
    {
        this.lineTerminator = lineTerminator;
        write(content);
    }

    public final void writeln(string s)
    in
    {
        assert(s !is null);
    }
    body
    {
        write(s ~ lineTerminator);
    }

    public final void write(string s)
    in
    {
        assert(s !is null);
    }
    body
    {
        synchronized
        {
            _content ~= s;
        }
    }
}

// TESTS

@("OutputStringStream stores content appropriately")
unittest
{
    import unit_threaded : shouldEqual;

    immutable string lineTerminator = "\n\r"; // Use something other than the default
    immutable string initializerContent = "Content passed in the initializer" ~ lineTerminator;

    auto stream = new shared OutputStringStream(initializerContent, lineTerminator);

    stream.content.shouldEqual(initializerContent);

    immutable string startOfLine1 = "This is the start of line 1...";
    stream.write(startOfLine1);

    stream.content.shouldEqual(initializerContent ~ startOfLine1);

    immutable string endOfLine1 = "... and this is the end of line 1";
    stream.writeln(endOfLine1);

    stream.content.shouldEqual(initializerContent ~ startOfLine1 ~
                               endOfLine1 ~ lineTerminator);
}

@("OutputStringStream can be written to from multiple threads")
unittest
{
    import unit_threaded : shouldEqual;

    import std.string : count;
    import core.thread : ThreadGroup;

    immutable string toBeWritten = "This is what each thread should write, plus the default line terminator";

    auto stream = new shared OutputStringStream();

    auto threadGroup = new ThreadGroup();

    enum threadsToUse = 20;

    for(size_t i; i < threadsToUse; i++)
        threadGroup.create(
            {
                stream.writeln(toBeWritten);
            });

    threadGroup.joinAll();

    stream.content.count(toBeWritten ~ stream.lineTerminator).shouldEqual(threadsToUse);
}