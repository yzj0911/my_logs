# 

# 深入理解计算机系统


# 深入理解计算机系统


## 一、计算机系统漫游

计算机系统是由`硬件`和`软件`组成。

### 1.1 信息就是位 + 上下文

系统中所有的信息——包括磁盘文件、内存中的程序、内存中存放的用户数据以及网络上传送的数据，都是由一串 bit 表示的。区分不同数据对象的唯一方法是我们读到这些数据对象是的上下文。

### 1.2 程序被其他程序翻译成不同的格式

![编译系统](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210831190321.png)
### 1.3 了解编译系统如何工作是大有益处的

为什么程序员必须要知道编译系统是如何工作的?

- 优化程序性能。
- 理解链接时出现的错误。
- 避免安全漏洞。

### 1.4 处理器读并解释储存在内存中指令

系统硬件组成

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210901205400.png)

1. 总线: 贯穿整个系统的一组电子管道，称作总线，他携带信息字节并负责在各个部件间传递。
2. I/O 设备: 系统与外部世界的联系通道。每个 I/O 设备都通过一个控制器或者适配器与 I/O 总线相连。控制器和适配器之间的区别主要在于它们的封装方式。控制器是 I/O 设备本身或者系统的主印制电路板上的芯片组。而适配器则是一块插在主板插槽上的卡。
3. 主存: 主存是一个临时存储设备，在处理执行程序时，用来存放程序和程序处理的数据。从物理上来说，主存是由一组动态随机存储存储器 (DRAM) 芯片组成的。从逻辑上来说，存储器是一个线性的字节数组，每个字节都有其唯一的地址(数组索引)，这些地址是从零开始的。
4. 处理器：中央处理单元 (CPU)，简称处理器，是解释(或)执行存储在主存中指令的引擎、处理器的核心是一个大小与一个字的存储设备(或寄存器)，称为程序计数器(PC)。在任何时刻，PC 都指向主存中的某条机器语言指令。

系统执行一个 `Hello World` 程序时，硬件运行流程。

1. 键盘输入命令时，shell 程序将字符逐一读入寄存器，再存放到内存中。
2. 键入回车键后，shell 执行一系列指令来加载可执行的 hello 文件，将 hello 目标文件中的代码和数据从磁盘复制到内存。
3. 处理器开始执行 hello 程序 main 程序中的机器语言指令。
4. 这些指令将输出的字符串中的字节从主存复制到寄存器文件，再从寄存器文件中复制到显示设备，最终显示在屏幕上。

### 1.5 高速缓存至关重要

系统运行时会频繁的挪动信息，而不同存储设备之间的读写性能有严重偏差 (从寄存器中读取数据比从主存中读取快 100 被，从主存中读取又比磁盘中快 1000 万倍)。所以不同存储设备间需要高速缓存来提供系统运行速度。

> 这里的高速缓存是相对概念。

### 1.6 存储设备形成层次结构

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210901212609.png)

### 1.7 操作系统管理硬件

我们并不直接访问硬件，而是通过操作系统。所有应用程序对硬件的操作尝试都必须通过操作系统。

操作系统有两个基本功能:

- 防止硬件被失控的应用程序滥用。
- 向应用程序提供简单一致的机制来控制复杂而又通常不大相同的低级硬件设备。

操作系统通过几个基本抽象概念来实现这两个功能。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210901214102.png)

进程: 操作系统对一个正在运行的程序的一种抽象。

上下文: 操作系统保持跟踪进程运行所需的所有状态信息，其中包含 PC 和寄存器文件的当前值，以及主存的内存。

在任何一个时刻，单处理器系统都只能执行一个进程的代码。当操作系统决定要把控制权从当前进程转移到某个新进程时，就会进行上下文切换。这一过程有操作系统内核 (kernel) 管理。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210901213718.png)

线程: 现代操作系统中，一个进程实际上可以由多个称为线程的执行单元组成，每个线程都裕兴在进程的上下文中，并共享同样的代码和全局数据。

虚拟机内存是一个抽象概念，它为每个进程提供一个假象，即每个进程都在独占地使用主存，每个进程看到的内存都是一致的，称为虚拟地址空间。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210901214306.png)

虚拟地址空间从下至上依次为:

- 程序代码和数据。对所有的进程来说，代码是从同一固定地址开始，紧接着的是和 C 全局变量相对应的数据位置。代码和数据区是直接按照可执行目标文件的内容初始化的。
- 堆。堆可以在运行时动态地扩展和收缩。
- 共享库。存放 C 标准库和数学库这些共享库的代码和数据。
- 栈。位于用户虚拟地址空间顶部，编译器用它来实现函数调用，它和堆一样在程序运行期间可以动态地扩展和收缩。每次调用一个函数时，栈就会增长，从一个函数返回时，栈就会收缩。
- 内核虚拟内存。地址空间顶部的区域是为内核保留的。不允许应用程序读写这个区域的内容或者直接调用内核代码定义的函数。相反，他们必须调用内核来执行这些操作。

文件就是字节序列！每个 I/O 设备，包括磁盘、键盘、显示器，甚至网络，都可以看成文件。

### 1.8 系统之间利用网络通信

硬件和软件组合成一个系统，而通过网络间不同的主机连接成一个更广大的现代系统。

### 1.9 重要主题

并发 (concurrency): 一个同时具有多个活动的系统。

并行 (parallelism): 用并发来是一个系统运行得更快。

超线程：有时称为同时多线程 (simultaneous multi-threading)，是一项允许一个 CPU 执行多个控制流的技术。

抽象的使用是计算机科学中最为重要的概念之一。这里介绍四个抽象:

- 文件是对 I/O 设备的抽象。
- 虚拟内存是对程序存储器的抽象。
- 进程是对一个正在运行的程序的抽象。
- 虚拟机是对整个计算机的抽象。

## 三、程序的机器级表示

### 3.1 历史观点

Intel 处理器系列俗称 `x86`。

摩尔定律: 1965 年， Gordon Moore, Intel 公司的创始人根据当时的芯片技术做出推断，预测在未来 10 年，芯片上的晶体管数量每年都会翻一番。这个预测就成为摩尔定律。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210906193611.png)

### 3.2 程序编码

机器级编程重要的两种抽象:

- 由指令级体系结构或指令集架构(Instruction Set Architecture, ISA) 来定义机器级程序的格式和行为，它定义了处理器状态、指令的格式，以及每条指令对状态的影响。
- 机器级程序使用的内存地址是虚拟地址，提供的内存模型看上去是一个非常大的字节数组。

汇编代码非常接近于机器代码，它的主要特点是它用可读性更好的文本格式表示。

程序内存包含：程序的可执行机器代码，操作系统需要的一些信息，用来管理过程调用和返回的运行时栈，以及用户分配的内存块。

一条机器指令只能执行一个非常基本的操作。

### 3.3 数据格式

Intel 中数据格式：

- 字 word: 表示 16 位数据类型
- 双字 double words: 32 位数
- 四字 qoad words: 64 位数

C 语言数据类型在 x86-64 中的大小。在 64 为机器中，指针长 8 字节。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210906202049.png)

大多数`GCC`生成的汇编代码指令都有一个字符的后缀，表明操作数的大小。例如。数据传送指令有四个变种：

- movb: 传送字节
- movw: 传送字
- movl: 传送双字
- movq: 传送四字

### 3.4 访问信息

一个 `x86-64` 的中央处理单元 CPU 包含一组 16 个存储 64 位值的通用目的寄存器，这些寄存器用来存储整数数据和指针。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907213431.png)

关于寄存器的说明可以参考:

- [X86-64 寄存器和栈帧](https://blog.csdn.net/u013982161/article/details/51347944)
- [x86_64 寄存器介绍](https://lenzhao.com/topic/597acd202e95f0fd0a981868)

大多数指令有一个或多个操作数(operand)，指示出执行一个操作中要使用到的源数据值，以及放置结果的目的位置。

存放操作数的类型：

- 立即数(immediate)，用来表示常数值。格式是 '$' 后面跟一个标准 C 表示法表示的整数。比如 `$-577`或`$0x1F`。
- 寄存器(register)，它表示某个寄存器的内容，用符号 $R_a$ 表示。
- 内存引用，它会根据计算出来的地址(通常称为有效地址)访问某个内存位置。使用 $M_b$[Addr] 表示对存储在内存中从 _Addr_ 开始的 b 个字节值的引用。

多种不同的寻址方式，允许不同形式的内存引用。

Imm($r_b$, $r_i$, s) : 一个立即数偏移 Imm，一个基址寄存器 $r_b$，一个变址寄存器 $r_i$ 和一个比例因子 s，s 必须是 1、2、4、8。基址和变址寄存器都必须是 64 位寄存器。有效地址为 Imm+R[$r_b$]+R[$r_i$]\*s。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907204700.png)

计算题:
有以下内存地址和寄存器的值:

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907210324.png)

得出以下操作数的值:
| 操作数 | 值 | 注释|
|---|---|---|
|%rax|0x100|寄存器|
|0x104|0xAB|绝对地址|
|$0x108|0x108|立即数|
|(%rax)|0xFF|地址 0x100|
|4(%rax)|0xAB|地址 0x104|
|9(%rax,%rdx)|0x11|地址 0x10C|
|260(%rax,%rdx)|0x13|地址 0x108|
|OxFC(,%rcx,4)|0xFF|地址 0x100|
|(%rax,%rdx,4)|0x11|地址 0x10C|

数据传送指令: 将数据从一个位置复制到另一个位置。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907211404.png)

源操作数指定的值是一个立即数，存储在寄存器或者内存中。目的操作数指定一个位置，寄存器或者内存地址。

> x86-64 中传送指令的两个操作数不能都指向内存位置，内存间的复制需要两条指令。

`MOV` 的五种可能组合:
```asm
movl $0x4050, $eax        ; Immediate -- Register, 4 bytes
movw %bp, %sp             ; Register -- Register,  2 bytes
movb (%bp, %rcx), %al     ; Memory -- Register,    1 bytes
movb $-17, (%rsp)         ; Immediate -- Memory,   1 bytes
movq %rax, -12(%rbp)      ; Register -- Memory,    8 bytes
```

`MOVZ` 类中指令把目的中剩余的字节填充为0。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907212410.png)

`MOVS` 类中的指令通过符号扩展来填充，把源操作的最高为进行复制。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210907212339.png)

下面是一个数据传送示例:
```c
long exchange(long *xp, long y)
{
    long x = *xp;
    *xp = y;
    return x;
}
```
执行命令 `gcc -Og -S main.c` 生成以下汇编内容:
```asm
exchange:
        movq    (%rdi), %rax
        movq    %rsi, (%rdi)
        ret
```
可以看出: C 语言的 "指针" 其实就是地址。间接引用指针就是间该指针放在一个寄存器中，然后再内存引用中使用这个寄存器。

最后的两个数据传送操作: 将数据压入程序栈中，从程序栈中弹出数据。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210908212726.png)

```asm
pushq %rbp        ; 栈指针减8，然后将值写到新的栈顶地址。
; 等同于
subq $8, %rsp     ; Decrement stack pointer
movq %rbp, (%rsp) ; Store %rbp on stack
```
操作示意图:
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210908213559.png)

```asm
popq %rbp         ; 弹出一个四字的操作包括从栈顶位置读出数据，然后减栈指针加8。
; 等同于
movq %rsp, (%rax) ; Read %rax from stack
addq $8, %rsp     ; Increment stack pointer
```
### 3.5 算术和逻辑操作
指令类 ADD 由四条加法指令组成: `addb` 字节加法、`addw` 字加法、`addl` 双字加法 和 `addq` 四字加法。

这些操作被分成四组: 加载有效地址、一元操作、二元操作和移位。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210908213818.png) 

加载有效地址(load effective address)指令 `leaq` 实际上是 `movq` 指令的变形。它的指令形式是从内存读数据到寄存器，但实际上它根本就没有引用内存。
```c
long scale(long x, long y, long z) {
    long t = x + 4 * y + 12 * z;
    return t;
}
```
得到汇编命令:
```asm
_scale:                                 ## @scale
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	(%rdi,%rsi,4), %rax
	leaq	(%rdx,%rdx,2), %rcx
	leaq	(%rax,%rcx,4), %rax
	popq	%rbp
	retq
```

一元操作数只有一个操作数，既是源又是目的。如 `incq (%rsp)`。

二元操作数，第二个操作数既是源又是目的。如 `subq %rax,%rdx`。

移位操作，先给出移位量，然后第二项是要移位。可以进行算术和逻辑右移。位移量可以是一个立即数，或者放在单字节寄存器 %cl 中(移位操作指令只允许以这个特定的寄存器作为操作数)。

特殊的算术操作

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210909085314.png)

以下的 C 代码:
```C
#include <inttypes.h>

typedef unsigned __int128 uint128_t;

void store_uprod(uint128_t *dest, uint64_t x, uint64_t y) {
    *dest = x * (uint128_t) y;
}

void remdiv(long x, long y,
            long *qp, long *rp) {
    long q = x / y;
    long r = x%y;
    *qp = q;
    *rp = r;
}
```
生成汇编
```asm
store_uprod:
	movq	%rsp, %rbp
	movq	%rdx, %rax      ; Copy x to multiplicand
	mulq	%rsi            ; Multiply by y
	movq	%rdx, 8(%rdi)   ; Store upper 8 bytes at dest+8
	movq	%rax, (%rdi)    ; Store lower 8 bytes at dest
	retq

remdiv:
	movq	%rsp, %rbp
	movq	%rdx, %r8       ; Copy qp
	movq	%rdi, %rax      ; Move x to lower 8 bytes of dividend
	cqto                  ; Sign-extend to upper 8 bytes of dividend
	idivq	%rsi            ; Divide by y 
	movq	%rax, (%r8)     ; Store remainder at rp
	movq	%rdx, (%rcx)    ; Store quotient at qp
	retq
```

### 3.6 控制
CPU 还维护着一组单个位的条件码 (condition code) 寄存器，它们描述了最近的算术或逻辑操作的属性。可以检测这些寄存器来执行条件分支指令。最常用的条件码有:
- CF: 进位标志。最近的操作使最高位产生了进位。可以来检查无符号操作的溢出。
- ZF: 零标志。最近的操作得出的结果为0。
- SF: 符号标志。最近的操作得到的结果为负数。
- OF: 溢出标志。最近的操作导致一个补码溢出 —— 正溢出或负溢出。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210909124413.png)

条件码通常不会直接读取，常用的使用方法有三种:
- 可以根据条件码的某种组合，将一个字节设置为 0 或者 1。
- 可以条件跳转到程序的某个其他部分。
- 可以有条件地创送数据。

`SET` 指令是根据条件码的某种组合，将一个字节设置为 0 或者 1的一整类指令。这些指令的后缀表示不同的条件而不是操作数的大小。如 
- `setl` 表示 “小于时设置 (set less)”。
- `setb` 表示 “低于时设置 (set below)”。

一条 `SET` 指令的目的操作数是低位单字节寄存器元素之一，或者是一个字节的内存位置，指令会将这个字节设置成 0 或者 1。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210909125357.png)

跳转 (jump) 指令会导致执行切换到程序中一个全新的位置。在汇编代码中，这些跳转的目的地通常用一个标号 (label) 指明。
```asm
  movq $0,%rax        ; Set %rax to 0
  jmp .L1             ; Goto .L1
  movq (%rax), %rdx   ; Null pointer dereference (skipped)
.L1:
  popq %rdx           ; Jump target
``` 
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210909170813.png)

实现条件操作的传统方法是通过使用控制的条件转移。当条件满足时，程序沿着一条执行路径执行，而当条件不满足是，就走另一条路径。但这个方法在现代处理器上可能会非常低效。

另一种策略是使用数据的条件转移。这个方法计算一个条件操作的两种结果，然后再根据条件是否满足从中选取一个。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210909190735.png)

汇编中没有循环指令存在，可以用条件测试和跳转组合起来实现循环效果。
```C
long fact_do(long n) {
    long result = 1;
    do {
        result *= n;
        n = n - 1;
    } while (n > 1);
    return result;
}
```
生成汇编代码:
```asm
_fact_do:                               ## @fact_do
	pushq	%rbp
	movq	%rsp, %rbp
	movl	$1, %eax
LBB0_1:                                 ## =>This Inner Loop Header: Depth=1
	imulq	%rdi, %rax
	decq	%rdi
	cmpq	$1, %rdi
	jg	LBB0_1
	popq	%rbp
	retq
```

switch 语句可以根据一个整数索引值进行多重分支 (multiway branching)。switch 会被转化成跳转表 (jump table)。跳转表示一个数组，表项 i 是一个代码段的地址，这个代码段实现当开关索引值等于 i 时程序应该采取的动作。程序代码用开关索引值来执行一个跳转表内的数组引用，确定跳转指令的目标。和使用一组很长的 if-else 语句对比，使用跳转表的优点是执行开关语句的时间与开关情况的数量无关。

C switch 代码:
```C
void switch_eg(long x, long n,
               long *dest) {
    long val = x;

    switch (n) {
        case 100:
            val *= 13;
            break;

        case 102:
            val += 10;

        case 103:
            val += 11;
            break;

        case 104:
        case 106:
            val *= val;
            break;

        default:
            val = 0;
    }
    *dest = val;
}
```
生成汇编:
```asm
	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 10, 15, 4	sdk_version 10, 15, 4
	.globl	_switch_eg              ## -- Begin function switch_eg
	.p2align	4, 0x90
_switch_eg:                             ## @switch_eg
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	xorl	%eax, %eax
	addq	$-100, %rsi
	cmpq	$6, %rsi
	ja	LBB0_7
## %bb.1:
	leaq	LJTI0_0(%rip), %rcx
	movslq	(%rcx,%rsi,4), %rsi
	addq	%rcx, %rsi
	jmpq	*%rsi
LBB0_5:
	imulq	%rdi, %rdi
	jmp	LBB0_6
LBB0_2:
	leaq	(%rdi,%rdi,2), %rax
	leaq	(%rdi,%rax,4), %rax
	jmp	LBB0_7
LBB0_3:
	addq	$10, %rdi
LBB0_4:
	addq	$11, %rdi
LBB0_6:
	movq	%rdi, %rax
LBB0_7:
	movq	%rax, (%rdx)
	popq	%rbp
	retq
```

### 3.7 过程
过程是软件中一种很重要的抽象。它提供了一种封装代码的方式，用一组指定的参数和一个可选的返回值实现了某种功能。然后，可以在程序中不同的地方调用这个函数。设计良好的如软件用过程作为抽象机制，隐藏某个行为的具体实现，同时又提供清晰简洁的接口定义，说明要计算的是哪些值，过程会对程序状态产生说明样的影响。

不同编程语言中，过程的形式:
- 函数 (function)
- 方法 (method)
- 子例程 (subroutine)
- 处理函数 (handler)

假设过程 P 调用过程 Q，Q 执行后返回 P。过程可能用到的一个或多个机制:
- 传递控制。在进入过程 Q 的时候，程序计数器必须被设置为 Q 的代码的起始地址，然后再返回时，要把程序计数器设置为 P 中调用 Q 后面那条指令的地址。
- 传递数据。P 必须能够向 Q 提供一个或多个参数，Q 必须能够向 P 返回一个值。
- 分配和释放内存。在开始是，Q 可能需要为局部变量分配空间，而在返回前，又必须释放这些存储空间。

#### 3.7.1 传递控制
C 语言过程调用中使用栈数据结构提供的后进先出的内存管理原则。

程序可以用栈来管理它的过程所需要的存储空间，栈和程序寄存器存放这传递控制和数据、分配内存所需要的信息。当 P 调用 Q 时，控制和数据信息添加到栈尾。当 P 返回时，这些信息会释放掉。

当 `x86-64` 过程需要的存储空间超出寄存器能够存放的大小时，就会在栈上分配空间。这个部分称为过程的栈帧(stack frame)。当前正在执行的过程的帧总是在栈顶。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210910082909.png)

#### 3.7.2 转移控制
将控制从函数 P 转移到函数 Q 只需要简单地把程序计数器(PC)设置为 Q 的代码的起始位置。不过，当稍后从 Q 返回的时候，处理器必须记录好需要继续 P 的执行的代码位置。在 x86-64 机器中，这个信息是用指令 `call Q` 调用过程 Q 来记录的。该指令会把地址 A 压入栈中，并将 PC 设置为 Q 的起始地址。压入的地址 A 被称为返回地址，是紧跟在 call 指令后面的那条指令的地址。对应的指令 ret 会从栈中弹出地址 A，并把 PC 设置为 A。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210910084602.png)

call 指令有一个目标，即指明被调用过程起始的指令地址。同调整一样，调用可能是直接的，也可以是间接的。在汇编代码中，直接调用的目标是一个标号，而间接调用的目标是 * 后面跟讴歌操作数指示符。

#### 3.7.3 数据创送
数据传送: 当调用一个过程时，除了要把控制传递给它并在过程返回时再传递回来之外，过程调用还可能包括吧数据作为参数传递，而从过程返回还有可能包括返回一个值。

`x86-64`中，可能通过寄存器最多传递 6 个整型(例如整数和指针)参数。寄存器的使用是由特殊顺序的，寄存器使用的名字取决于要传递的数据类型的大小。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210910090642.png)

如果一个函数有大于 6 个整型参数，超出 6 个的部分就要通过栈来传递。
```C
void proc(long a1, long *a1p,
          int a2, int *a2p,
          short a3, short *a3p,
          char a4, char *a4p) {

    *a1p += a1;
    *a2p += a2;
    *a3p += a3;
    *a4p += a4;
}
```
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210910091803.png)

#### 3.7.4 栈上的局部存储
需要栈上局部存储的情况:
- 寄存器不能足够存放素有的本地数据。
- 对一个局部变量使用地址运算符 '&', 因此必须能够为他产生一个地址。
- 某些局部变量是数组或结构，因此必须能够通过数据或结构引用被访问到。

```C
long call_proc() {
    long x1 = 1;
    int x2 = 2;
    short x3 = 3;
    char x4 = 4;
    proc(x1, &x1, x2, &x2, x3, &x3, x4, &x4); // 创建栈帧
    return (x1 + x2) * (x3 - x4);
}
```
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210910092035.png)

#### 3.7.5 寄存器中的局部存储空间
寄存器组是唯一被所有过程共享的资源，为了防止寄存器的值在被一个过程使用时，不被其他过程调用导致值被覆盖，`x86-64` 采用一组统一的寄存器使用惯例:
- 寄存器 %rbx、%rbp 和 %r12~%r15 被划分为被调用者寄存器，Q 过程必须保证寄存器值的安全。
- 除了栈指针 %rsp, 都分类为调用者保存寄存器。

#### 3.7.6 递归过程
递归调用一个函数本身与调用其他函数时一样的。栈规则提供了一种机制，每次函数调用都有它自己私有的状态信息(保存的返回位置和被调用者保存寄存器的值)存储空间。如果需要，它还可以提供局部变量的存储。栈分配和释放的规则很自然就与函数调用-返回的循序匹配。这种实现函数调用和返回的方法甚至对更复杂的情况也适用，暴扣互相递归调用。
```C
long rfact(long n) {
    long result;
    if (n <= 1) {
        result = 1;
    } else {
        result = n * rfact(n - 1);
    }
    return result;
}
```
对应汇编代码:
```asm
rfact:
    pushq   %rbx
    movq    %rdi, rbx
    movl    $1, %eax
    cmpq    $1, %rdi
    jle     .L35
    leaq    -1(%rdi), %rdi
    call    rfact
    imulq   %rbx, %rax
.L35:
    popq    %rbx
    ret
```
### 3.8 数组分配和访问
C 语言的数组是一种将标量数据聚集成更大数据类型的方式。

#### 3.8.1 基本原则
对于数据类型 *T* 和整型常数 *N*，声明如下: 

*T* A[*N*];

起始位置表示为 $x_A$。这个声明有两个效果。首先，它在内存中分配一个 L·N 字节的连续区域。这里 L 是数据类型 *T* 的大小(单位为字节)。其次，它引入了标识符 A，可以用 A 来作为指向数组开头的指针，这个指针的值就是 $x_A$。可用用 0~N-1 的证书索引来访问该数组元素。数组元素 i 会被存放在地址为 $x_A$+L·i 的地方。

#### 3.8.2 指针运算
C 语言允许对指针进行运算，而计算出来的值会根据该指针引用的数据类型的大小进行伸缩。也就是说，如果 p 是一个指向类型为 *T* 的数据的指针，p 的值为 $x_p$，那么表达式 p+i 的值为 $x_p$+L·i，这里 *L* 是数据类型 *T* 的大小。

单操作数操作符 '$' 和 '* ' 可以产生指针和间接引用指针。对于一个表示某个对象的表达式 `Expr`，`&Expr` 是该对象的一个指针。对于一个表示地址的表达式 `AExpr`, `*AExpr` 是该地址的值。因此，表达式 `Expr` 与 `* &Expr` 是等价的。可以对数组和指针应用数组下标操作。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210911092013.png)

#### 3.8.3 嵌套数组
要访问多维数组的元素，编译器会以数组起始为基地址，偏移量为索引，产生计算期望的元素偏移量，然后使用某种 MOV 指令。

通常来说，对于一个声明如下的数组: `T D[R][C]` 的元素 `D[i][j]` 的内存地址为 $$ D[i][j] = x_D+L(C·i+j) $$

#### 3.8.4 定长数组
C语言编译器能够优化定长多维数组上的操作代码

### 3.9 异质的数据结构
C 语言2提供了两种将不同类型的对象组合到一起创建数据类型的机制: 
- 结构 (structure)，关键字 struct，将多个对象集合到一个单位中。
- 联合 (union)，用关键字 union 来声明，允许用几种不同的类型来引用一个对象。

#### 3.9.1 结构
C 语言的 struct 声明创建一个数据类型，将可能不同类型的对象聚合到一个对象中。用名字来引用结构的各个组成部分。类似于数组的实现，结构的所有组成部分都存放在内存中一段连续的区域内，而指向结构的指针就是结构第一个字节的地址。
```C
struct rect {
    int i;
    int j;
    int a[2];
    int *p;
};
```
该结构在内存中的布局:

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210911111340.png)

#### 3.9.2 联合
联合提供了一种方式，能够规避 C 语言的类型系统，允许以多种类型来引用一个对象。一个联合的总的大小等于它最大字段的大小。

在一些上下文中，联合十分有用。但是，它也能引起一些讨厌的错误，因为他们绕过了 C 语言类型系统提供的安全措施。一种应用情况是，我们事先知道对一个数据结构中的两个不同字段的使用是互斥的，那么将这两个字段声明为联合的一部分，而不是结构的一部分，会减小分配空间的总量。

#### 3.9.3 数据对齐
许多计算机系统对基本数据类型的合法地址做出了一些限制，要求某种类型对象的地址必须是某个值 *K* (通常是2、4或8)的倍数。这种对齐限制简化了形成处理器和内存系统之间接口的硬件设计。

无论数据是否对齐，`x86-64` 硬件都能正确工作。不过，Intel 还是建议要对齐数据以提高内存系统的性能。对齐原则是任何 *K* 字节的基本对象的地址必须是 *K* 的倍数。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210911130649.png)

确保每种数据类型都是按照指定方式来组织和分配，即每种类型的对象都满足它的对齐限制，就可保证实施对齐。编译器在汇编代码中放入命令，指明全局数据所需的对齐。
```asm
.align 8
```
这命令就保证了它后面的数据的开始地址是 8 的倍数。因为每个表项长 8 个字节，后面的元素都会遵守 8 字节对齐的限制。

对于包含结构的代码，编译器可能需要在字段的分配中插入间隙，以保证每个结构元素都满足它的对齐要求。而结构本身对它的起始地址也有一些对齐要求。

假设如下的结构声明:
```C
struct S1 {
    int i;
    char c;
    int j;
}
```
如果编译器用最小的9字节分配，内存布局会是这样:

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210911171439.png)

但是它不满足字段 i 和 j 的4字节对齐要求，所以编译器在字段 c 和 j 之间插入一个 3 字节的间隙:

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210911171552.png)

### 3.10 在机器级程序中将控制与数据结合起来

#### 3.10.1 理解指针
一些指针和它们映射到机器代码的关键原则:
- 每个指针都对应一个类型。这个类型表明该指针指向的是哪一类对象。
- 每个指针都有一个值。这个值是某个指定类型的对象的地址。特殊的 NULL(0) 值表示该指针没有指向任何地方。
- 指针用 '&' 运算符创建。
- *操作符用于间接引用指针。其结果是一个值，它的类型与该指针的类型一致。间接引用是用内存来实现的，要么是存储到一个指定的地址，要么是从指定的地址读取。
- 数组与指针紧密联系。一个数组的名字可以像一个指针变量一样引用(但是不能修改)。
- 将指针从一种类型强制转化成另一个类型，只改变它的类型，而不改变它的值。强制类型转换的一个效果是改变指针运算的伸缩。
- 指针也可以指向函数。这提供了一个很强大的存储和向代码传递引用的功能，这个引用可以被程序的某个其他部分调用。

函数指针:
```C
#include <stdio.h>

int fun(int x, int *p);

int (*fp)(int, int *);


int main() {
    fp = fun;

    int y = 1;
    int result = fp(3, &y);
    printf("%d\n", result);
}


int fun(int x, int *p) {
    *p += x;
    return *p;
}
```

### 3.11 浮点代码
处理器的浮点系统结构包括多个方面，会影响对浮点数据操作的程序如何被映射到机器上，包括:
- 如何存储和访问浮点数据。通常是通过某种寄存器方式来完成。
- 对浮点数据操作的指令。
- 向函数传递浮点数参数和从函数返回浮点数结构的规则。
- 函数调用过程中保存寄存器的规则。

`x86-64` 浮点体系结构的历史:

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913085103.png)

如图所示，AVX 浮点体系结构允许数据存储在 16 个 YMM 寄存器中，名字是 `%ymm0~%ymm15`。每个 YMM 寄存器都是 256(32 字节)。当对标量数据操作时，这些寄存器值保存浮点数，而且只使用低 32 位(对于 float) 或 64 位(对于 double)。汇编代码用寄存器的 SSE XMM 寄存器名字 `%xmm0~%xmm15` 来引用它们，每个 XMM 寄存器都是对应的 YMM 寄存器的低 128 位(16字节)。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913085612.png)

#### 3.11.1 浮点传送和转化操作

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913090024.png)

`GCC` 只用标量传送操作从内存传送数据到 XMM 寄存器或从 XMM 寄存器传送数据到内存。对于在两个 XMM 寄存器之间传送数据，`GCC` 会使用两种指令之一，即用 `vmpovaps` 传送单精度数，用 `vmovapd` 传送双精度数。对于这些情况，程序复制整个寄存器还是只复制低位值。既不会影响程序功能，也不会影响执行速度，所以使用这些指令还是针对标量数据的人指令没有实质上的差别。指令名字中的字母 'a' 表示 "aligned(对齐的)"。当用于读写内存是，如果地址不满足16字节对齐，它们会导致异常。在两个寄存器之间传送数据，绝不会出现错误对齐的状况。

浮点数和整数数据类型之间以及不同浮点格式之间进行转换的指令集合。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913091445.png)

把一个从 XMM 寄存器或内存中读出的浮点值进行转换，并将结果写入一个通用寄存器。把浮点值转换成整数时，指令会执行截断(truncation)，把值向 0 进行舍入。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913091717.png)

#### 3.11.2 过程中的浮点代码
在 `x86-64` 中，XMM 寄存器用来向函数传递浮点参数，以及从函数返回浮点值。具有以下规则:
- XMM 寄存器 `%xmm0~%xmm7` 最多可以传递 8 个浮点参数。按照参数列出的顺序使用这些寄存器。可以通过栈传递额外的浮点参数。
- 函数使用寄存器 %xmm0 来返回浮点值。
- 所有的 XMM 寄存器都是调用者保存的。被调用者可以不同保存就覆盖这些寄存器中任意一个。

当函数包含指针、整数和浮点数混合的参数时，指针和整数通过通用寄存器传递，而浮点值通过 XMM 寄存器传递。也就是说，参数到寄存器的映射取决于它们的类型和排列的顺序。例如:
```C
// 这个函数会把 x 存放在 %edi 中，y 放在 %xmm0 中，z 放在 %rsi 中。
double f1(int x, double y, long z);
// 这个函数的寄存器分配与函数 f1 相同。
double f2(double y, int x, long z);
// 这个函数会将 x 放在 %xmm0 中，y 放在 %rdi 中，z 放在 %rsi 中。
double f1(float x, double *y, long *z);
```

#### 3.11.3 浮点运算操作
下图描述了一组执行算术运算的标量 AVX2 浮点指令。每条指令有一个($S_1$)或两个($S_1, S_2$)，和一个目的操作数 *D*。第一个源操作数 $S_1$ 可以是一个 XMM 寄存器或一个内存位置。第二个源操作数和目的操作数都必须是 XMM 寄存器。每个操作多有一条针对当精度的指令和一条针对双精度的指令。结果存放在目的寄存器中。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913093055.png)

#### 3.11.4 定义和使用浮点常数
和整数运算操作不同，AVX 浮点操作不能以立即数值作为操作数。相反，编译器必须为所有的常量值分配和初始化存储空间。然后代码再把这些值从内存读入。

#### 3.11.5 在浮点代码中使用位级操作

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913125840.png)

#### 3.11.6 浮点比较操作

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210913125948.png)

浮点比较指令会设置三个条件码: 零标志位 ZF, 进位标志位 CF 和奇偶标志位 PF。


