module dli.input_string_stream;

import core.sync.semaphore;

public shared class InputStringStream
{
    private string _content ="";

    @property
    public string content() const
    out(s)
    {
        assert(s !is null);
    }
    body
    {
        return _content;
    }

    private Semaphore linesAvailableSemaphore;

    public immutable string lineTerminator;
    
    public this(string content = "", string lineTerminator = "\n")
    in
    {
        assert(content !is null);
        assert(lineTerminator !is null);
    }
    body
    {
        linesAvailableSemaphore = cast(shared) new Semaphore();
        this.lineTerminator = lineTerminator;

        appendContent(content);
    }

    public final void appendLine(string content)
    in
    {
        assert(content !is null);
    }
    body
    {
        appendContent(content ~ lineTerminator);
    }

    public final void appendContent(string content)
    in
    {
        assert(content !is null);
    }
    body
    {
        import std.string : count;

        immutable size_t linesInContent = content.count(lineTerminator);

        synchronized(this)
            _content ~= content;

        for (size_t i; i < linesInContent; i++)
            (cast() linesAvailableSemaphore).notify();
    }

    public string readln()
    out(line)
    {
        assert(line[$-lineTerminator.length..$] == lineTerminator);
    }
    body
    {
        import std.string : indexOf;

        ptrdiff_t lineTerminatorPosition;

        string line;

        (cast() linesAvailableSemaphore).wait();

        synchronized(this)
        {
            // Reaquire value for lineTerminatorPosition in case another thread
            // was blocking this one from entering the synchronized block
            lineTerminatorPosition = _content.indexOf(lineTerminator);
            // Extract line and remove it from _content
            line = _content[0..lineTerminatorPosition + lineTerminator.length];
            _content = _content[lineTerminatorPosition + lineTerminator.length..$];
        }

        return line;
    }
}

// TESTS
@("InputStringStream reads out contents one line at a time regardless of line terminator")
unittest
{
    import unit_threaded : shouldEqual;

    string line1 = "This is line 1";
    string line2 = "This is line 2";

    string lineTerminator1 = "\n";

    auto stream1 = new shared InputStringStream(line1 ~ lineTerminator1 ~
                                                 line2 ~ lineTerminator1, lineTerminator1);

    stream1.readln().shouldEqual(line1 ~ lineTerminator1);
    stream1.readln().shouldEqual(line2 ~ lineTerminator1);

    string lineTerminator2 = "\n\r";

    auto stream2 = new shared InputStringStream(line1 ~ lineTerminator2 ~
                                                 line2 ~ lineTerminator2, lineTerminator2);

    stream2.readln().shouldEqual(line1 ~ lineTerminator2);
    stream2.readln().shouldEqual(line2 ~ lineTerminator2);
}

@("InputStringStream blocks threads on readln until a line is available")
unittest
{
    import unit_threaded : shouldEqual;

    import core.thread : ThreadGroup;
    import core.atomic : atomicOp;


    auto stream = new shared InputStringStream();
    immutable string sampleLine = "This is a sample line\n";

    ThreadGroup threads = new ThreadGroup();
    enum lines = 20;
    shared size_t linesRead;

    for(size_t i; i < lines; i++)
    {
        threads.create(
            {
                stream.readln().shouldEqual(sampleLine);
                linesRead.atomicOp!"+="(1);
            });

        threads.create(
            {
                stream.appendContent(sampleLine);
            });
    }

    threads.joinAll();

    linesRead.shouldEqual(lines);
}