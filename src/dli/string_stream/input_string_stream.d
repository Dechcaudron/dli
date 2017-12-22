module dli.string_stream.input_string_stream;

import core.sync.semaphore;
import dli.string_stream.eof_exception;
import std.exception;
import std.string;

public enum char EOF = '\x04';

public shared class InputStringStream
{
    private string _content ="";
    private bool eofInserted; /// Whether eof has been insterted by append
    private bool eofReached; /// Whether eof has been reached by readln

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
        immutable size_t EOFs_encountered = content.count(EOF);
        assert(EOFs_encountered <= 1);
        if(EOFs_encountered > 0)
            assert(content.endsWith(EOF));
    }
    body
    {
        enforce!EOFException(!eofInserted, "Cannot append content after EOF has been inserted");
        eofInserted = content.endsWith(EOF);

        // Determine number of lines that will become available to read after this append.
        // if the content ends with EOF, it is made available as an additional line if the
        // previous character is not a line terminator
        immutable size_t linesInContent = content.count(lineTerminator) + 
                                            (eofInserted &&
                                            !content[0..$-1].endsWith(lineTerminator) ? 1 : 0); // TODO: test

        synchronized(this)
            _content ~= content;

        for (size_t i; i < linesInContent; i++)
            (cast() linesAvailableSemaphore).notify();
    }

    public string readln()
    {
        import std.string : indexOf;

        if(eofReached)
            return null;

        (cast() linesAvailableSemaphore).wait();

        synchronized(this)
        {
            if(_content[0] == EOF)
            {
                _content = [];
                return null;
            }
            else
            {
                ptrdiff_t nextLineTerminatorPosition = _content.indexOf(lineTerminator);
                immutable bool contentAfterLineTerminator = (nextLineTerminatorPosition + 
                                                            lineTerminator.length) < _content.length;
                immutable bool reachedEOF = (nextLineTerminatorPosition != -1) ? 
                                            contentAfterLineTerminator &&
                                            (_content[nextLineTerminatorPosition + lineTerminator.length] == EOF) :
                                            _content.endsWith(EOF);
                // Extract line and remove it from _content
                string line;
                if(reachedEOF)
                {
                    line = _content[0..$-1];
                    _content = [];
                    eofReached = true;
                }
                else
                {
                    line = _content[0..nextLineTerminatorPosition + lineTerminator.length];
                    _content = _content[nextLineTerminatorPosition + lineTerminator.length..$];
                }
                return line;
            }
            
        }
    }
}

// TESTS
version(unittest)
{
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
                    stream.append(sampleLine);
                });
        }

        threads.joinAll();

        linesRead.shouldEqual(lines);
    }

    @("InputStringStream.readln() returns null if the only content is EOF")
    unittest
    {
        auto stream = new shared InputStringStream();
        stream.append("" ~ EOF);
        assert(stream.readln() is null);
    }

    @("InputStringStream.readln() returns content before EOF, up to a line, " ~
      "and null after EOF has been reached")
    unittest
    {
        auto stream = new shared InputStringStream();
        stream.append("abc" ~ EOF);
        assert(stream.readln() == "abc");
        assert(stream.readln() is null);

        auto stream2 = new shared InputStringStream();
        stream2.appendLine("abc");
        stream2.append("" ~ EOF);
        assert(stream2.readln() == "abc" ~ stream2.lineTerminator);
        assert(stream2.readln() is null);

        auto stream3 = new shared InputStringStream();
        stream3.appendLine("abc");
        stream3.appendLine("def");
        stream3.append("" ~ EOF);
        assert(stream3.readln() == "abc" ~ stream3.lineTerminator);
        assert(stream3.readln() == "def" ~ stream3.lineTerminator);
        assert(stream3.readln() is null);
    }

    @("InputStringStream throws EOFException if you try to append content after EOF")
    unittest
    {
        auto stream = new shared InputStringStream();
        stream.append("hello" ~ EOF);
        assertThrown!EOFException(stream.append(""));
    }
}