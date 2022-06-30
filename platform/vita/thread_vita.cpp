/*************************************************************************/
/*  thread.cpp                                                           */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2022 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2022 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#include "platform_config.h"

#include "platform_thread.h"
#include <psp2/kernel/clib.h>

#include "core/script_language.h"

#if !defined(NO_THREADS)

#include "core/safe_refcount.h"

Error (*Thread::set_name_func)(const String &) = nullptr;
void (*Thread::set_priority_func)(Thread::Priority) = nullptr;
void (*Thread::init_func)() = nullptr;
void (*Thread::term_func)() = nullptr;

Thread::ID Thread::main_thread_id = sceKernelGetThreadId();
static thread_local Thread::ID caller_id = 0;
static thread_local bool caller_id_cached = false;

void Thread::_set_platform_funcs(
		Error (*p_set_name_func)(const String &),
		void (*p_set_priority_func)(Thread::Priority),
		void (*p_init_func)(),
		void (*p_term_func)()) {
	Thread::set_name_func = p_set_name_func;
	Thread::set_priority_func = p_set_priority_func;
	Thread::init_func = p_init_func;
	Thread::term_func = p_term_func;
}

int Thread::callback(uint32_t argSize, void *pArgBlock) {
    sceClibPrintf("Callback Cast\n");
    ThreadData *data = (ThreadData *)(pArgBlock);
    sceClibPrintf("Callback Enter\n");
    ScriptServer::thread_enter(); //scripts may need to attach a stack
    sceClibPrintf("Callback Run\n");
    printf("Thread Data in Thread: %p\n", data->userdata);
	data->callback(data->userdata);
    sceClibPrintf("Callback Exit\n");
	ScriptServer::thread_exit();
    sceClibPrintf("Callback Over\n");
    return 0;
}

void Thread::start(Thread::Callback p_callback, void *p_user, const Settings &p_settings) {
	sceClibPrintf("New Thread\n");
    ThreadData data;
    data.callback = p_callback;
    data.userdata = p_user;
    printf("Thread Data: %p\n", p_user);
	id = sceKernelCreateThread("GodotThread", Thread::callback, 0x10000100, 0x4000, 0, 0, NULL);
    sceKernelStartThread(id, sizeof(ThreadData), &data);
	sceClibPrintf("Created Thread\n");
}

bool Thread::is_started() const {
	return id >= 0;
}

void Thread::wait_to_finish() {
	sceClibPrintf("Finish Thread\n");
	if (id != -1) {
		ERR_FAIL_COND_MSG(id == sceKernelGetThreadId(), "A Thread can't wait for itself to finish.");
		sceKernelWaitThreadEnd(id, NULL, NULL);
        sceKernelDeleteThread(id);
        id = -1;
	}
	sceClibPrintf("Finished Thread\n");
}

Error Thread::set_name(const String &p_name) {
	return ERR_UNAVAILABLE;
}

Thread::~Thread() {
	sceClibPrintf("Delete Thread\n");
	if (id != -1) {
#ifdef DEBUG_ENABLED
		WARN_PRINT("A Thread object has been destroyed without wait_to_finish() having been called on it. Please do so to ensure correct cleanup of the thread.");
#endif
		sceKernelDeleteThread(id);
	}
	sceClibPrintf("Deleted Thread\n");
}

Thread::ID Thread::get_caller_id() {
	if (likely(caller_id_cached)) {
		return caller_id;
	} else {
		caller_id = sceKernelGetThreadId();
		caller_id_cached = true;
		return caller_id;
	}
}
#endif
