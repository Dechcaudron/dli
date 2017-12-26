module dli.string_stream.input_string_stream;

import core.sync.semaphore;
import std.exception;
import std.string;

public enum char eof = '\x04';

public shared class InputStringStream
{
    private string _content = "";

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

        append(content);
    }

    public final void appendLine(string content)
    in
    {
        assert(content !is null);
    }
    body
    {
        append(content ~ lineTerminator);
    }

    public final void append(string content)
    in
    {
        assert(content !is null);
    }
    body
    {
        // Determine number of lines that will become available to read after this append.
        immutable size_t linesInContent = content.count(lineTerminator) + content.count(eof) * 2;

        synchronized(this)
            _content ~= content;

        for (size_t i; i < linesInContent; i++)
            (cast() linesAvailableSemaphore).notify();
    }

    public string readln()
    {
        import std.string : indexOf;
        import std.algorithm.comparison : min;

        (cast() linesAvailableSemaphore).wait();

        synchronized(this)
        {
            if(_content[0] == eof)
            {
                _content = _content[1..$];
                return null;
            }
            else
            {

                immutable ptrdiff_t nextLineTerminatorPosition = _content.indexOf(lineTerminator);
                immutable ptrdiff_t nextEOFPosition = _content.indexOf(eof);
                immutable ptrdiff_t lineUpperLimit = 
                    (nextEOFPosition != -1) && (nextLineTerminatorPosition != -1) ?
                        min(nextEOFPosition, nextLineTerminatorPosition + lineTerminator.length) :
                        (nextEOFPosition != -1) ?
                            nextEOFPosition :
                            nextLineTerminatorPosition + lineTerminator.length;
                // Extract line and remove it from _content
                string line = _content[0..lineUpperLimit];
                _content = _content[lineUpperLimit..$];
                return line;
            }
            
        }
    }
}

// TESTS
version(unittest)
{
    import unit_threaded : shouldEqual;
    @("InputStringStream reads out contents one line at a time regardless of line terminator")
    unittest
    {
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
                    stream.append(sampleLine);
                });
        }

        threads.joinAll();

        linesRead.shouldEqual(lines);
    }

    @("InputStringStream.readln() returns null if the next character is eof")
    unittest
    {
        auto stream = new shared InputStringStream();
        stream.append("" ~ eof ~ "asdf");
        stream.readln().shouldEqual(null);
    }

    @("InputStringStream.readln() returns content before eof, up to a line")
    unittest
    {
        auto stream = new shared InputStringStream();
        stream.append("abc" ~ eof);
        stream.readln().shouldEqual("abc");
        stream.readln().shouldEqual(null);

        stream.appendLine("def");
        stream.append("" ~ eof);
        stream.readln().shouldEqual("def" ~ stream.lineTerminator);
        stream.readln().shouldEqual(null);

        stream.appendLine("abc");
        stream.appendLine("def");
        stream.append("" ~ eof);
        assert(stream.readln() == "abc" ~ stream.lineTerminator);
        assert(stream.readln() == "def" ~ stream.lineTerminator);
        assert(stream.readln() is null);
    }
}