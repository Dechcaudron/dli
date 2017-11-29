module dli.string_stream;

public shared class StringStream
{
    private string _content;
    public static enum lineTerminator = '\n';

    @property
    public void content(in string s)
    in
    {
        assert(s !is null);
    }
    body
    {
        _content = s;
    }

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

    this(in string content = "")
    in
    {
        assert(content !is null);
    }
    body
    {
        _content = content;
    }

    public void writeln(in string s)
    {
        _content = _content ~ s ~ lineTerminator;
    }

    public string readln()
    out(line)
    {
        assert(line !is null);
        assert(line[$-1] == lineTerminator);
    }
    body
    {
        import std.string : indexOf;

        ptrdiff_t endOfLinePosition;

        // TODO: manage proper threading lock for this
        do
        {
            endOfLinePosition = _content.indexOf(lineTerminator);
        }
        while(endOfLinePosition == -1);

        string line = _content[0..endOfLinePosition + 1];
        // Extract the line from _content, including line terminator. If this is the last line,
        // content is simply set to an empty string
        _content = _content.length > line.length ? _content[endOfLinePosition + 1..$] : "";

        return line;
    }
}

// TESTS

@("StringStream stores given strings via constructor and properties")
unittest
{
    string constructorArg = "constructorArg";

    auto myStream = new shared StringStream(constructorArg);
    assert(myStream.content == constructorArg);

    myStream.content = "";
    assert(myStream.content == "");

    string randomContent = "sbfsìdfaosfo\nosdasdoaisd\r";
    myStream.content = randomContent;
    assert(myStream.content == randomContent);
}

@("StringStream writes given lines with line terminator")
unittest
{
    auto myStream = new shared StringStream();
    string line1 = "Content of first line";
    string line2 = "Content of second line";

    myStream.writeln(line1);
    myStream.writeln(line2);

    assert(myStream.content == (line1 ~ StringStream.lineTerminator ~ 
                                line2 ~ StringStream.lineTerminator));
}

@("StringStream reads lines one at a time")
unittest
{
    string line1 = "Content of first line";
    string line2 = "Content of second line";
    auto myStream = new shared StringStream(line1 ~ StringStream.lineTerminator ~
                                            line2 ~ StringStream.lineTerminator);

    assert(myStream.readln() == line1 ~ StringStream.lineTerminator);
    assert(myStream.readln() == line2 ~ StringStream.lineTerminator);
}

@("StringStream readln removes lines from content")
unittest
{
    string line1 = "Content of first line";
    string line2 = "Content of second line";
    auto myStream = new shared StringStream(line1 ~ StringStream.lineTerminator ~
                                            line2 ~ StringStream.lineTerminator);

    myStream.readln();
    assert(myStream.content == line2 ~ StringStream.lineTerminator);

    myStream.readln();
    assert(myStream.content == "");
}

///
@("StringStream reads out lines previously written to it")
unittest
{
    string line1 = "Content of first line";
    string line2 = "Content of second line";
    string line3 = "Content of third line";
    auto myStream = new shared StringStream();

    myStream.writeln(line1);
    assert(myStream.readln() == line1 ~ StringStream.lineTerminator);

    myStream.writeln(line2);
    myStream.writeln(line3);
    assert(myStream.readln() == line2 ~ StringStream.lineTerminator); 
    assert(myStream.readln() == line3 ~ StringStream.lineTerminator); 
}

// TODO multithreading tests