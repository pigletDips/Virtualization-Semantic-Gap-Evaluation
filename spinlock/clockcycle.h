
unsigned long Now(void)
{
#ifdef __AARCH64__
    unsigned long physical_timer_value;
    
    asm volatile(
		    " isb			\n"
		    " mrs %0, cntpct_el0	\n" 
		    " isb			\n"
		    : "=r"(physical_timer_value)
		    :
		    : 
		    );
    return physical_timer_value;
#endif

#ifdef __x86_64__
/*
// some VMs doesn't support cpuid instruction
    unsigned long low, high;
    asm volatile(
	             "cpuid\n\t"       
	             "rdtsc\n\t"        
	             "mov %%rdx, %0\n\t"   
	             "mov %%rax, %1\n\t"
	             "cpuid\n\t" :
		     "=r" (high), "=r" (low)::  
	             "%rax", "%rbx", "%rcx", "%rdx" );
    return ( ((unsigned long)high << 32) | low  ); 
*/
    unsigned long low, high;
    asm volatile(
	             " mfence		\n\t" 
	             " lfence		\n\t"	     
	             " rdtsc		\n\t" 
	      	     " lfence		\n\t"	     
	             " mov %%rdx, %0	\n\t"   
	             " mov %%rax, %1	\n\t"
		     :"=r" (high), "=r" (low)
		     :
		     :"%rax", "%rbx", "%rcx", "%rdx" );
    return ( ((unsigned long)high << 32) | low  ); 

/*    
    unsigned long long cycles;
    __asm__  __volatile__(
		    " mfence		\n"
		    " lfence		\n"
		    " rdtsc		\n"
		    " lfence		\n"
		    :"=A"(cycles)
		    );
    return cycles;
*/
#endif
 
}

static inline unsigned long get_cntfrq(void)
 {
      unsigned long val;
      asm volatile("mrs %0, cntfrq_el0" : "=r" (val));
      return val;
 }



