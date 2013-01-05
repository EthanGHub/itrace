/* //////////////////////////////////////////////////////////////////////////////////////
 * includes
 */
#include "prefix.h"
#include "arm.h"
#include "x86.h"
#include "x64.h"
#include <sys/mman.h>
#include <mach/mach.h>
#include <stdarg.h>
#include <sys/types.h>
#include <pthread.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <Foundation.h>
#include <CoreFoundation.h>
#include "asl.h"

/* //////////////////////////////////////////////////////////////////////////////////////
 * macros
 */

// trace
#define it_trace(fmt, arg ...)						do { asl_log(TB_NULL, TB_NULL, 4, "[itrace]: " fmt , ## arg); } while (0)

// check
#define it_check_return(x)							do { if (!(x)) return ; } while (0)
#define it_check_return_val(x, v)					do { if (!(x)) return (v); } while (0)
#define it_check_goto(x, b)							do { if (!(x)) goto b; } while (0)
#define it_check_break(x)							{ if (!(x)) break ; }
#define it_check_continue(x)						{ if (!(x)) continue ; }

// assert
#if IT_DEBUG
# 	define it_assert(x)								do { if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); } } while(0)
# 	define it_assert_return(x)						do { if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); return ; } } while(0)
# 	define it_assert_return_val(x, v)				do { if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); return (v); } } while(0)
# 	define it_assert_goto(x, b)						do { if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); goto b; } } while(0)
# 	define it_assert_break(x)						{ if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); break ; } }
# 	define it_assert_continue(x)					{ if (!(x)) { it_trace("[assert]: expr: %s, func: %s, line: %d, file: %s:", #x, __FUNCTION__, __LINE__, __FILE__); continue ; } }
# 	define it_assert_and_check_return(x)			it_assert_return(x)
# 	define it_assert_and_check_return_val(x, v)		it_assert_return_val(x, v)
# 	define it_assert_and_check_goto(x, b)			it_assert_goto(x, b)
# 	define it_assert_and_check_break(x)				it_assert_break(x)
# 	define it_assert_and_check_continue(x)			it_assert_continue(x)
#else
# 	define it_assert(x)
# 	define it_assert_return(x)
# 	define it_assert_return_val(x, v)
# 	define it_assert_goto(x, b)
# 	define it_assert_break(x)
# 	define it_assert_continue(x)
# 	define it_assert_and_check_return(x)			it_check_return(x)
# 	define it_assert_and_check_return_val(x, v)		it_check_return_val(x, v)
# 	define it_assert_and_check_goto(x, b)			it_check_goto(x, b)
# 	define it_assert_and_check_break(x)				it_check_break(x)
# 	define it_assert_and_check_continue(x)			it_check_continue(x)
#endif

// the root
#define IT_ROOT 			"/tmp/"
#define IT_PATH_CFG 		IT_ROOT "itrace.xml"

/* //////////////////////////////////////////////////////////////////////////////////////
 * globals
 */
static tb_xml_node_t* 		g_cfg = TB_NULL;

/* //////////////////////////////////////////////////////////////////////////////////////
 * declaration
 */

// clear cache for gcc
tb_void_t 		__clear_cache(tb_char_t* beg, tb_char_t* end);

// pool
tb_pointer_t 	objc_autoreleasePoolPush();
tb_void_t 		objc_autoreleasePoolPop(tb_pointer_t pool);

/* //////////////////////////////////////////////////////////////////////////////////////
 * implementation
 */
static tb_void_t it_chook_method_puts(tb_xml_node_t const* node, Method method, ...)
{
	it_assert_and_check_return(node && method);

	// the class name
	tb_char_t const* cname = tb_pstring_cstr(&node->name);
	it_assert_and_check_return(cname);

	// tracing arguments?
	tb_bool_t args = TB_TRUE;
	if (node->ahead
		&& !tb_pstring_cstricmp(&node->ahead->name, "args")
		&& !tb_pstring_cstricmp(&node->ahead->data, "0"))
	{
		args = TB_FALSE;
	}

	if (args)
	{
		// init info
		tb_char_t 	info[4096] = {0};
		tb_char_t* 	data = info;
		tb_long_t 	maxn = 4095;
		tb_long_t 	size = 0;
		
		// init pool
		//tb_pointer_t pool = objc_autoreleasePoolPush();
		//if (pool)
		{
			// the method name
			tb_char_t const* mname = sel_getName(method_getName(method));

			// init args
			tb_va_list_t vl;
			tb_va_start(vl, method);
		
			// the arguments
			tb_size_t argi = 0;
			tb_size_t argn = method_getNumberOfArguments(method);
			tb_char_t type[512 + 1];
			for (argi = 2; argi < argn && maxn > 0; argi++)
			{
				memset(type, 0, 513);
				method_getArgumentType(method, argi, type, 512);
				it_trace("type: %s", type);
#if defined(TB_ARCH_ARM)
				if (argi == 4)
				{
					__tb_volatile__ tb_size_t r0 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r1 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r2 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r3 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r4 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r5 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r6 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r7 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r8 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r9 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t lr = tb_va_arg(vl, tb_size_t);
				}
#elif defined(TB_ARCH_x86)
				if (argi == 2)
				{
					__tb_volatile__ tb_size_t edi = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t esi = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t ebp = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t esp = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t ebx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t edx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t ecx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t eax = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t flags = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t ret = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t sef = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t sel = tb_va_arg(vl, tb_size_t);
				}
#elif defined(TB_ARCH_x64)				
				if (argi == 6)
				{
					__tb_volatile__ tb_size_t r15 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r14 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r13 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r12 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r11 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r10 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r9 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t r8 = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rsi = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rdi = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rdx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rcx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rbx = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t rax = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t flags = tb_va_arg(vl, tb_size_t);
					__tb_volatile__ tb_size_t ret = tb_va_arg(vl, tb_size_t);
				}
#endif
				if (!strcmp(type, "@"))
				{
#if 0
					tb_pointer_t 		o = tb_va_arg(vl, tb_pointer_t);
					it_trace("11111111: %p", o);
					tb_pointer_t 		d = o && [o respondsToSelector:@selector(description)]? [o description] : TB_NULL;
					it_trace("22222222: %p", d);
					tb_char_t const* 	s = d? [d UTF8String] : TB_NULL;
					it_trace("33333333: %p", s);
					size = tb_snprintf(data, maxn, ": %s", s);
					it_trace("44444444: %ld", size);
#else
					id 					o = tb_va_arg(vl, id);
					it_trace("11111111: %p", o);
					tb_pointer_t 		d = o? CFCopyDescription((CFTypeRef)o) : TB_NULL;
					it_trace("22222222: %p", d);
					if (d && CFStringGetCString(d, data + 2, maxn - 2, kCFStringEncodingUTF8))
					{
						data[0] = ':';
						data[1] = ' ';
						size = tb_strlen(data);
						it_trace("44444444: %ld", size);
					}				
#endif
				}
				else if (!strcmp(type, ":"))
				{
					SEL 				sel = tb_va_arg(vl, SEL);
					tb_char_t const*	sel_name = sel? sel_getName(sel) : TB_NULL;
					size = tb_snprintf(data, maxn, ": @selector(%s)", sel_name);
				}
				else if (!strcasecmp(type, "f"))
				{
					size = tb_snprintf(data, maxn, ": %f", tb_va_arg(vl, tb_float_t));
				}
				else if (!strcasecmp(type, "i"))
				{				
					size = tb_snprintf(data, maxn, ": %ld", tb_va_arg(vl, tb_long_t));
				}
				else if (!strcasecmp(type, "c"))
				{
					size = tb_snprintf(data, maxn, ": %lu", tb_va_arg(vl, tb_size_t));
				}
				else if (!strcasecmp(type, "r*"))
				{
					size = tb_snprintf(data, maxn, ": %s", tb_va_arg(vl, tb_char_t const*));
				}
				else 
				{
					size = tb_snprintf(data, maxn, ": <type(%s)>", type);
					__tb_volatile__ tb_size_t p = tb_va_arg(vl, tb_size_t);
				}

				if (size > 0)
				{
					data += size;
					maxn -= size;
				}
			}
			
			// exit args
			tb_va_end(vl);

			// trace
			it_trace("[%lx]: [%s %s]%s", (tb_size_t)pthread_self(), cname, mname? mname : "", info);

			// exit pool
			//objc_autoreleasePoolPop(pool);
			
		}
	}
	else
	{
		// the method name
		tb_char_t const* mname = sel_getName(method_getName(method));
		it_trace("[%lx]: [%s %s]", (tb_size_t)pthread_self(), cname, mname? mname : "");
	}
}
static __tb_inline__ tb_size_t it_chook_method_size_for_class(tb_char_t const* class_name)
{
	it_assert_and_check_return_val(class_name, 0);

	tb_size_t 	method_n = 0;
	Method* 	method_s = class_copyMethodList(objc_getClass(class_name), &method_n);

	if (method_s) free(method_s);
	method_s = TB_NULL;

	return method_n;
}
static __tb_inline__ tb_pointer_t it_chook_method_done_for_class(tb_xml_node_t const* node, tb_pointer_t mmapfunc, tb_cpointer_t mmaptail)
{
	// check
	it_assert_and_check_return_val(node && mmapfunc && mmaptail, mmapfunc);

	// the class name
	tb_char_t const* class_name = tb_pstring_cstr(&node->name);
	it_assert_and_check_return_val(class_name, mmapfunc);

	// init method list
	tb_size_t 	method_n = 0;
	Method* 	method_s = class_copyMethodList(objc_getClass(class_name), &method_n);
//	it_trace("class: %s, method: %u", class_name, method_n);
	it_assert_and_check_return_val(method_n && method_s, mmapfunc);

	// walk methods
	tb_size_t i = 0;
	for (i = 0; i < method_n; i++)
	{
		Method method = method_s[i];
		if (method)
		{
			// the selector
//			SEL sel = method_getName(method);

			// the imp
			IMP imp = method_getImplementation(method);

			// trace
//			it_trace("[%s %s]: %p", class_name, sel_getName(sel), imp);

			// ok?
			if (imp)
			{
				// hook
#if defined(TB_ARCH_ARM)
				tb_uint32_t* p = (tb_uint32_t*)mmapfunc;
				it_assert_and_check_break(p + 11 <= mmaptail);
				*p++ = A$push$r0_r9_lr$;
				*p++ = A$movw_rd_im(A$r0, ((tb_uint32_t)node) & 0xffff);
				*p++ = A$movt_rd_im(A$r0, ((tb_uint32_t)node) >> 16);
				*p++ = A$movw_rd_im(A$r1, ((tb_uint32_t)method) & 0xffff);
				*p++ = A$movt_rd_im(A$r1, ((tb_uint32_t)method) >> 16);
				*p++ = A$movw_rd_im(A$r9, ((tb_uint32_t)&it_chook_method_puts) & 0xffff);
				*p++ = A$movt_rd_im(A$r9, ((tb_uint32_t)&it_chook_method_puts) >> 16);
				*p++ = A$blx(A$r9);
				*p++ = A$pop$r0_r9_lr$;
				*p++ = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
				*p++ = (tb_uint32_t)imp;
				method_setImplementation(method, (IMP)mmapfunc);
				mmapfunc = p;
#elif defined(TB_ARCH_x86)
				tb_byte_t* p = (tb_byte_t*)mmapfunc;
				it_assert_and_check_break(p + 32 <= mmaptail);

				x86$pushf(p);
				x86$pusha(p);
				x86$push$im(p, (tb_uint32_t)method);
				x86$push$im(p, (tb_uint32_t)node);
				x86$mov$eax$im(p, (tb_uint32_t)&it_chook_method_puts);
				x86$call$eax(p);
				x86$pop$eax(p);
				x86$pop$eax(p);
				x86$popa(p);
				x86$popf(p);

				x86$push$im(p, (tb_uint32_t)imp);				
				x86$ret(p);

//				while (((tb_uint32_t)p & 0x3)) x86$nop(p);				
				x86$nop(p);
				x86$nop(p);
				x86$nop(p);

				it_assert_and_check_break(!((tb_uint32_t)p & 0x3));
				method_setImplementation(method, (IMP)mmapfunc);
				mmapfunc = p;
#elif defined(TB_ARCH_x64)
				tb_byte_t* p = (tb_byte_t*)mmapfunc;
				it_assert_and_check_break(p + 96 <= mmaptail);

				// 78-bytes
				x64$pushf(p);
				x64$push$rax(p);
				x64$push$rbx(p);
				x64$push$rcx(p);
				x64$push$rdx(p);
				x64$push$rdi(p);
				x64$push$rsi(p);
				x64$push$r8(p);
				x64$push$r9(p);
				x64$push$r10(p);
				x64$push$r11(p);
				x64$push$r12(p);
				x64$push$r13(p);
				x64$push$r14(p);
				x64$push$r15(p);
				x64$mov$rdi$im(p, (tb_uint64_t)node);
				x64$mov$rsi$im(p, (tb_uint64_t)method);
				x64$mov$rbx$im(p, (tb_uint64_t)&it_chook_method_puts);
				x64$call$rbx(p);
				x64$pop$r15(p);
				x64$pop$r14(p);
				x64$pop$r13(p);
				x64$pop$r12(p);
				x64$pop$r11(p);
				x64$pop$r10(p);
				x64$pop$r9(p);
				x64$pop$r8(p);
				x64$pop$rsi(p);
				x64$pop$rdi(p);
				x64$pop$rdx(p);
				x64$pop$rcx(p);
				x64$pop$rbx(p);
				x64$pop$rax(p);
				x64$popf(p);

				// 14-bytes
//				x64$sub$rsp$im(p, 0x8);
//				x64$mov$rsp$im(p, (tb_uint32_t)imp);
				x64$push$im(p, (tb_uint32_t)imp);
				x64$mov$rsp4$im(p, (tb_uint32_t)((tb_uint64_t)imp >> 32));
				x64$ret(p);

//				while (((tb_uint32_t)p & 0x7)) x64$nop(p);
				x64$nop(p);
				x64$nop(p);
				x64$nop(p);
				x64$nop(p);
//				x64$nop(p);
//				x64$nop(p);

				it_assert_and_check_break(!((tb_uint32_t)p & 0x7));
				method_setImplementation(method, (IMP)mmapfunc);
				mmapfunc = p;	
#endif
			}
		}
	}

	// free it
	if (method_s) free(method_s);
	method_s = TB_NULL;

	// ok
	return mmapfunc;
}
static __tb_inline__ tb_size_t it_chook_method_size()
{
	// check
	it_assert_and_check_return_val(g_cfg, 0);

	// walk
	tb_xml_node_t* 	root = tb_xml_node_goto(g_cfg, "/itrace/class");
	tb_xml_node_t* 	node = tb_xml_node_chead(root);
	tb_size_t 		size = 0;
	while (node)
	{
		if (node->type == TB_XML_NODE_TYPE_ELEMENT) 
			size += it_chook_method_size_for_class(tb_pstring_cstr(&node->name));
		node = node->next;
	}

	// size
	return size;
}

static __tb_inline__ tb_pointer_t it_chook_method_done(tb_pointer_t mmapfunc, tb_cpointer_t mmaptail)
{
	// check
	it_assert_and_check_return_val(g_cfg, TB_NULL);

	// walk
	tb_xml_node_t* 	root = tb_xml_node_goto(g_cfg, "/itrace/class");
	tb_xml_node_t* 	node = tb_xml_node_chead(root);
	while (node)
	{
		if (node->type == TB_XML_NODE_TYPE_ELEMENT) 
			mmapfunc = it_chook_method_done_for_class(node, mmapfunc, mmaptail);
		node = node->next;
	}

	// ok
	return mmapfunc;
}
/* //////////////////////////////////////////////////////////////////////////////////////
 * init
 */
static __tb_inline__ tb_bool_t it_cfg_init()
{
	// check
	it_check_return_val(!g_cfg, TB_TRUE);

	// trace
	it_trace("init: cfg: ..");

	// init
	tb_gstream_t* gst = tb_gstream_init_from_url(IT_PATH_CFG);
	it_assert_and_check_return_val(gst, TB_FALSE);

	// open
	if (!tb_gstream_bopen(gst)) return TB_FALSE;

	// init reader
	tb_handle_t reader = tb_xml_reader_init(gst);
	if (reader)
	{
		// load
		g_cfg = tb_xml_reader_load(reader);
		it_assert(g_cfg);

		// exit reader & writer 
		tb_xml_reader_exit(reader);
	}
	
	// exit stream
	tb_gstream_exit(gst);

	// check
	if (!tb_xml_node_goto(g_cfg, "/itrace/class") && !tb_xml_node_goto(g_cfg, "/itrace/function"))
	{
		tb_xml_node_exit(g_cfg);
		g_cfg = TB_NULL;
	}

	// trace
	it_trace("init: cfg: %s", g_cfg? "ok" : "no");

	// ok
	return g_cfg? TB_TRUE : TB_FALSE;
}
static __tb_inline__ tb_bool_t it_chook_init()
{
	// check
	it_assert_and_check_return_val(g_cfg, TB_FALSE);

	// the method size
	tb_size_t method_size = it_chook_method_size();
	it_assert_and_check_return_val(method_size, TB_FALSE);
	it_trace("chook: method_size: %u", method_size);

	// init mmap base
#if defined(TB_ARCH_ARM)
	tb_size_t 		mmapmaxn = method_size * 11;
	tb_size_t 		mmapsize = mmapmaxn * sizeof(tb_uint32_t);
#elif defined(TB_ARCH_x86)
	tb_size_t 		mmapmaxn = method_size * 32;
	tb_size_t 		mmapsize = mmapmaxn;
#elif defined(TB_ARCH_x64)
	tb_size_t 		mmapmaxn = method_size * 96;
	tb_size_t 		mmapsize = mmapmaxn;
#endif

	tb_byte_t* 		mmapbase = (tb_byte_t*)mmap(TB_NULL, mmapsize, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
	it_assert_and_check_return_val(mmapbase != MAP_FAILED && mmapbase, TB_FALSE);
	it_trace("mmapmaxn: %u, mmapbase: %p", mmapmaxn, mmapbase);

	// hook
	tb_pointer_t 	mmaptail = it_chook_method_done(mmapbase, mmapbase + mmapmaxn);

	// clear cache
	if (mmapbase != mmaptail) __clear_cache(mmapbase, mmaptail);

	// protect: rx
	tb_long_t ok = mprotect(mmapbase, mmapsize, PROT_READ | PROT_EXEC);
	it_assert_and_check_return_val(!ok, TB_FALSE);

	// ok
	return TB_TRUE;
}
static tb_void_t __attribute__((constructor)) it_init()
{
	// trace
	it_trace("init: ..");

	// init cfg
	if (!it_cfg_init()) return ;

	// init chook	
	if (!it_chook_init()) return ;
	
	// trace
	it_trace("init: ok");
}
