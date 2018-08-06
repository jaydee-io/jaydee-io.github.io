---
layout: post
title: "Resource owning - Part 3 : Rule of zero"
published: true
tag: [C++, Rule of zero, Single Responsibility Principle, Passing parameter by value]
---
In the first two parts of this series on _resource owning_, we've seen some good practices about resource
owning: separating them from business code, how to offer a strong exception guarantee and how to have a
cleaner code with the _Copy and swap idiom_. We've also seen that if one of destructor, copy constructor,
copy assignment, move constructor, or move assignment operator is defined, all of them must also be defined,
as stated by the [Rule of five](https://en.cppreference.com/w/cpp/language/rule_of_three#Rule_of_five). In
this part, we'll see that this special member functions are only associated with resource owning classes,
and shouldn't be defined otherwise. But before that, we'll optimize our assignment operators.

This post is part of a series about _Resource owning_:
* [Resource owning - Part 1 : _Rule of three_]({{ site.baseurl }}{% post_url 2018-07-20-resource-owning-1 %})
* [Resource owning - Part 2 : _Rule of five_]({{ site.baseurl }}{% post_url 2018-07-31-resource-owning-2 %})
* [Resource owning - Part 3 : _Rule of zero_]({{ site.baseurl }}{% post_url 2018-08-06-resource-owning-3 %})

Let's start with the assignment operators.

## Passing parameter by value
At the end of the second post on this series, we ended up with the following implementation for the assignment
operators of our C++11 compliant `Buffer` class:

{% highlight C++ linenos %}
Buffer & Buffer::operator =(const Buffer & buffer) // (1)
{
    Buffer temp(buffer);
    swap(temp);

    return *this;
}

Buffer & Buffer::operator =(Buffer && buffer) // (2)
{
    Buffer temp(std::move(buffer));
    swap(temp);

    return *this;
}
{% endhighlight %}

This operators could be used like this:

{% highlight C++ linenos %}
Buffer b1(512);
Buffer b2(1024);
Buffer b3(2048);

b2 = b1; // Call (1)

b3 = std::move(b1); // Call (2)
b3 = Buffer(4096);  // Call (2)
{% endhighlight %}

But, looking closely we can see that this two assignment operators are implemented in the same way: they
create a local copy of the passed buffer, swap the copy with the current buffer, return a reference to the
current buffer and destroy the local copy. The only difference is in the way they create the local buffer: the
copy assignment operator _copy-construct_ it, while the move assignement operator _move-construct_ it.

Here, we can use another technique to reduce our code: _Passing parameters by value_. The goal is to replace the
two functions taking their parameters by reference or r-value reference, by a single one taking its parameter by
_value_. Also, the local object is now replaced by the parameter passed by value. The constructor, called to
create the parameter, now depends on the type of the argument passed at call site. If it's an _l-value_ (like
line 5 in the example), the copy constructor is called. Instead, if it's an _r-value_ (like lines 7 and 8), the
move constructor is called. These leads to the following single, and easy to read, implementation of the 
assignment operator:

{% highlight C++ linenos %}
Buffer & Buffer::operator =(Buffer buffer)
{
    swap(buffer);

    return *this;
}
{% endhighlight %}

In fact, in the assignment line 8, the move constructor isn't even called. At first sight, we could think that a 
4k temporary `Buffer` is created, then it is moved to the `buffer` argument by calling the move constructor. But 
in fact, due to the _copy elision_ optimisation (implemented by almost every compiler, and even mandatory with 
C++17) the `buffer` argument is directly constructed with the 4k buffer.

Now we have very clean implementation of our circular buffer:

{% highlight C++ linenos %}
class Buffer
{
public:
    explicit Buffer(size_t _capacity)
    : data(_capacity ? new uint8_t[_capacity] : nullptr)
    , capacity(_capacity)
    , start(-1)
    , end(-1)
    { }

    ~Buffer(void)
    {
        delete [] data;
    }

    Buffer(const Buffer & buffer)
    : data(buffer.capacity ? new uint8_t[buffer.capacity] : nullptr)
    , capacity(buffer.capacity)
    , start(buffer.start)
    , end(buffer.end)
    {
        std::copy_n(buffer.data, capacity, data);
    }

    Buffer(Buffer && buffer) noexcept
    : Buffer(0)
    {
        swap(buffer);
    }

    Buffer & operator =(Buffer buffer)
    {
        swap(temp);

        return *this;
    }

    void swap(Buffer & buffer) noexcept
    {
        std::swap(data,     buffer.data);
        std::swap(capacity, buffer.capacity);
        std::swap(start,    buffer.start);
        std::swap(end,      buffer.end);
    }

private:
    uint8_t * data;
    size_t    capacity;
    int       start;
    int       end;
};
{% endhighlight %}

## The rule of zero
With the rule of five, we saw that a resource owning class needs to have its 5 special member functions defined. 
But in 2012, R. Martinho Fernandes went further in his post named [Rule of zero](https://blog.rmf.io/cxx11/rule-of-zero) 
and ended with a stronger statement, that: 

> Classes that have custom destructors, copy/move constructors or copy/move assignment operators should
> deal exclusively with ownership. Other classes should not have custom destructors, copy/move constructors
> or copy/move assignment operators.
><footer class="blockquote-footer text-right"><cite title="R. Martinho Fernandes">R. Martinho Fernandes</cite></footer>
{:.blockquote .yoda}

And I think he's right :wink:. This is just a special case of application of the [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle)
principle. For example, say we have a class that doesn't define any of the 5 special member 
functions. And say that, for any reason (maybe we added a data member that cannot be moved), we need to add the 
move constructor. In this case, the move constructor and resource owning part of this class should be extracted 
and put in its own class to handle the resource. Leaving the original class without special member function.

For now, I haven't seen a class that need to define one of the 5 special member functions **and** that doesn't deal exclusively with ownership. If you do, please share it. There is only one use case I can think of: in C++, there is a special case where the destructor needs to be defined, but not necessarily the other special member functions and the class isn't owning a resource: inheritance.

## Special case of inheritance
Every good rule has its exceptions :wink:. In French, we like to say _'L'exception qui confirme la règle'_ (the 
exception that confirms the rule). There is one exception for the rule of zero (at least I can think of). In 
case of inheritance, the base class needs to have its destructor defined public and virtual. And doing this, 
prevents the implicitly compiler generated move constructor and assignment operator. But this base class, 
doesn't necessarily deal with ownership. In this special case, we simply need to declare all of them as 
defaulted:

{% highlight C++ linenos %}
class BaseClass
{
   public :
        virtual ~BaseClass(void) = default;

        BaseClass(const BaseClass &) = default;
        BaseClass(BaseClass &&) = default;
        BaseClass & operator =(const BaseClass &) = default;
        BaseClass & operator =(BaseClass &&) = default;
};
{% endhighlight %}

If this is an exception to the rule of zero, I don't think it's an exception to the rule of five. Even if the 5 
special member funtions are not _user defined_, they are still _user declared_ (in fact _user default declared_)
. And in this sense, respect the rule of five.

## Conclusion
Today, we saw some other good practices associated with resource owning. _Passing parameter by value_
is a good way to simplify both assignment operators. Also, classes that have custom destructors, copy/move 
constructors or copy/move assignment operators should deal exclusively with ownership. Other classes should not 
have custom destructors, copy/move constructors or copy/move assignment operators. An exception to this rule is 
the base class of inheritance. Do you see another exception ? Share it :wink: !
