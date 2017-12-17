module dli.internal.lifo;

package(dli) struct Lifo(T)
{
    private T[] array;

    @property
    public bool empty()
    {
        return array.length == 0;
    }

    public void put(T a)
    {
        array ~= a;
    }

    public T front()
    {
        return array[$-1];
    }

    public T pop()
    {
        auto a = array[$-1];
        array = array[0..$-1];
        return a;
    }
}

// TESTS
version(unittest)
{
    @("Lifo works as expected")
    unittest
    {
        auto lifo = Lifo!int();

        assert(lifo.empty);

        lifo.put(1);

        assert(!lifo.empty);

        lifo.put(2);
        lifo.put(3);

        assert(lifo.pop() == 3);
        assert(lifo.pop() == 2);
        assert(lifo.pop() == 1);
        assert(lifo.empty);
    }
}