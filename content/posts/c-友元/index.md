---
title: "C++友元"
date: 2021-12-03T10:17:16+08:00
draft: false
---


# C++友元


# 友元说明
相对于其他的编程语言，“友元”是C++中特别的一种语法。那它有什么作用呢？
`其实“友元”就是提供一种访问类私有部分的的方法`。如果没有“友元”，我们只能通过类本身提供的公有方法来访问，但相对地，这样限制太高了，所以“友元”就是一种的在类的封装性和实用性中很好的“折中”方式。

C++中的友元有三种：
- 友元函数
- 友元类
- 友元成员函数

C++中使用关键字`friend`来定义。

# 友元函数
这里直接用代码来说明：
```c++
#include <iostream>
#include <string>

class Person {
private:
    std::string account;
    std::string passwd;

public:
    Person(std::string ac, std::string pw);

    // 这里使用friend关键字，指定Point中的getPerson方法可以使用Person类的私有变量。
    friend void getPerson(Person &p);
};

Person::Person(std::string ac, std::string pw) {
    account = ac;
    passwd = pw;
}


void getPerson(Person &p) {
    // 因为定义了友元，这里就可以访问Person类的私有变量了。
    std::cout << "account: " << p.account
              << ", passwd: " << p.passwd << std::endl;
}

int main() {
    Person p("xingyys", "123456");

    getPerson(p);

    return 0;
}
```
这个例子还是比较简单的，只要在指定的方法中添加关键字就可以实现了。

# 友元类
在来一个例子说明：
```c++
#include <iostream>
#include <string>

class Tv {
private:
    int state;
    int volume;
    int maxchannel;
    int channel;
    int mode;
    int input;

public:
    // 在这里指定谁是他的友元
    friend class Remote;

    enum {
        Off, On
    };
    enum {
        MinVal, MaxVal = 20
    };
    enum {
        Antenna, Cable
    };
    enum {
        TV, DVD
    };

    Tv(int s = Off, int mc = 125) : state(s), volume(5),
                                    maxchannel(mc), channel(2), mode(Cable), input(TV) {}

    void onoff() { state = (state == On) ? Off : On; }

    bool ison() const { return state == On; }

    bool volup();

    bool voldown();

    void chanup();

    void chandown();

    void set_mode() { mode = (mode == Antenna) ? Cable : Antenna; }

    void set_input() { input = (input == TV) ? DVD : TV; }

    void settings() const;

};

class Remote {
private:
    int mode;

public:
    Remote(int m = Tv::TV) : mode(m) {}

    bool volup(Tv &t) { return t.volup(); }

    bool voldown(Tv &t) { return t.voldown(); }

    void onoff(Tv &t) { t.onoff(); }

    void chanup(Tv &t) { t.chanup(); }

    void chandown(Tv &t) { t.chandown(); }

    void set_chan(Tv &t, int c) { t.channel = c; }

    void set_mode(Tv &t) { t.set_mode(); }

    void set_input(Tv &t) { t.set_input(); }
};

bool Tv::volup() {
    if (volume < MaxVal) {
        volume++;
        return true;
    } else {
        return false;
    }
}

bool Tv::voldown() {
    if (volume > MinVal) {
        volume--;
        return true;
    } else {
        return false;
    }
}

void Tv::chanup() {
    if (channel < maxchannel)
        channel++;
    else
        channel = 1;
}

void Tv::chandown() {
    if (channel > 1)
        channel--;
    else
        channel = maxchannel;
}

void Tv::settings() const {
    using std::cout;
    using std::endl;
    cout << "TV is " << (state == Off ? "Off" : "On") << endl;
    if (state == On) {
        cout << "Volume setting = " << volume << endl;
        cout << "Channel setting = " << channel << endl;
        cout << "Mode = "
             << (mode == Antenna ? "antenna" : "cable") << endl;
        cout << "Input = "
             << (input == TV ? "TV" : "DVD") << endl;
    }
}

int main() {
    using std::cout;
    Tv s42;
    cout << "Initial setting for 42\" TV:\n";
    s42.settings();
    s42.onoff();
    s42.chanup();
    cout << "\nAdjusted setting for 42\" TV:\n";
    s42.chanup();
    cout << "\nAdjusted settings for 42\" TV:\n";
    s42.settings();

    Remote grey;

    grey.set_chan(s42, 10);
    grey.volup(s42);
    grey.volup(s42);
    cout << "\n42\" setting after using remote:\n";
    s42.settings();

    Tv s58(Tv::On);
    s58.set_mode();
    grey.set_chan(s58, 28);
    cout << "\n58\" settings:\n";
    s58.settings();
    return 0;
}
```

# 友元成员函数
```c++
#include <iostream>
#include <string>

class Person;

class Point {
public:
    void getPerson(Person &p);
};

class Person {
private:
    std::string account;
    std::string passwd;

public:
    Person(std::string ac, std::string pw);

    // 这里使用friend关键字，指定Point中的getPerson方法可以使用Person类的私有变量。
    friend void Point::getPerson(Person &p);
};

Person::Person(std::string ac, std::string pw) {
    account = ac;
    passwd = pw;
}


void Point::getPerson(Person &p) {
    // 因为定义了友元，这里就可以访问Person类的私有变量了。
    std::cout << "account: " << p.account
              << ", passwd: " << p.passwd << std::endl;
}

int main() {
    Person p ("xingyys", "123456");

    Point pt;

    pt.getPerson(p);

    return 0;
}
```

# 补充
- 不能定义类的对象。
- 可以用于定义指向这个类型的指针或引用。
- 用于声明(不是定义)，使用该类型作为形参类型或者函数的返回值类型。
- 友元关系不能被继承。
- 友元关系是单向的，不具有交换性。若类B是类A的友元，类A不一定是类B的友元，要看在类中是否有相应的声明。
- 友元关系不具有传递性。若类B是类A的友元，类C是B的友元，类C不一定是类A的友元，同样要看类中是否有相应的申明

