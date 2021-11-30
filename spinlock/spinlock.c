#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/rcupdate.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/ktime.h>
#include "clockcycle.h"

#define THREAD_NUM      16
#define ITERATION	5000

#define setbit(x,y)  x|=(1<<y)
#define clrbit(x,y)  x&=~(1<<y)
#define reversebit(x,y)  x^=(1<<y)

int i;
static uint32_t exit_count = 0x0000;
int loop[THREAD_NUM];
//ktime_t total[THREAD_NUM];
unsigned long total[THREAD_NUM];

struct task_struct *lock_thread[THREAD_NUM];

/* Initialize spinlock staticly
 * Multiple threads compete for spinlock0.
 */
DEFINE_SPINLOCK(spinlock0);

/*
#define BENCH_SPINLOCK(cpu) \
{ \
		get_cpu(); \
		total[cpu] = ktime_get(); \
		spin_lock(&spinlock0); \
		loop[0]++; \
		spin_unlock(&spinlock0); \
		total[cpu] = ktime_to_ns(ktime_sub(ktime_get(), total[cpu])); \
		put_cpu(); \
		printk("CPU = %d, SPIN = %llu ns\n", smp_processor_id(), total[cpu]); \
}
*/
#define BENCH_SPINLOCK(cpu) \
{ \
		spin_lock_irq(&spinlock0); \
		total[cpu] = Now(); \
		loop[0]++; \
		loop[0]++; \
		loop[0]++; \
		loop[0]++; \
		loop[0]++; \
		printk("cpu = %d\n", smp_processor_id()); \
		total[cpu] = Now() - total[cpu]; \
		printk("SPIN = %lu cycles\n", total[cpu]); \
		spin_unlock_irq(&spinlock0); \
}


/*
#define THREAD_BENCH_LOCK(cpu) \
	static int thread_bench_lock##cpu(void *data){ \
		setbit(exit_count, cpu); \
		while(!kthread_should_stop()){ \
			msleep(cpu + 1); \
			BENCH_SPINLOCK(cpu);\
		} \
		clrbit(exit_count, cpu); \
		return 0; \
	} 
*/

#define THREAD_BENCH_LOCK(cpu) \
	static int thread_bench_lock##cpu(void *data){ \
		int k; \
		for(k = 0; k < ITERATION; k++){ \
			msleep(1); \
			BENCH_SPINLOCK(cpu);\
		} \
		return 0; \
	} 


THREAD_BENCH_LOCK(0);
THREAD_BENCH_LOCK(1);
THREAD_BENCH_LOCK(2);
THREAD_BENCH_LOCK(3);
THREAD_BENCH_LOCK(4);
THREAD_BENCH_LOCK(5);
THREAD_BENCH_LOCK(6);
THREAD_BENCH_LOCK(7);


static int __init my_test_init(void)
{
        printk("[WS]: my spinlock module init\n");

	lock_thread[0] = kthread_run(thread_bench_lock0, NULL, "spinlock0");
	msleep(1);
	lock_thread[1] = kthread_run(thread_bench_lock1, NULL, "spinlock1");
	msleep(1);
	lock_thread[2] = kthread_run(thread_bench_lock2, NULL, "spinlock2");
	msleep(1);
	lock_thread[3] = kthread_run(thread_bench_lock3, NULL, "spinlock3");
	msleep(1);
	lock_thread[4] = kthread_run(thread_bench_lock4, NULL, "spinlock4");
	msleep(1);
	lock_thread[5] = kthread_run(thread_bench_lock5, NULL, "spinlock5");
	msleep(1);
	lock_thread[6] = kthread_run(thread_bench_lock6, NULL, "spinlock6");
	msleep(1);
	lock_thread[7] = kthread_run(thread_bench_lock7, NULL, "spinlock7");
	return 0;
}

static void __exit my_test_exit(void)
{
	/*
	int i;
	int ret;
	for(i = 0; i < THREAD_NUM; i++){
		if(!IS_ERR(lock_thread[i])){
			ret = kthread_stop(lock_thread[i]);
			printk(KERN_INFO "thread function return %d\n", ret);
		}
	}
	printk("%x\n", exit_count);
	while((exit_count & 0x1111) != 0x0000)
		msleep(1);
	msleep(100);
	*/
	msleep(1000);
        printk(KERN_EMERG"goodbye\n");
}

module_init(my_test_init);
module_exit(my_test_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("SONGWEI");

