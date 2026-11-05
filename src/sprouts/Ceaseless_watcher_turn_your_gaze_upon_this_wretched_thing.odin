package sprouts

import "base:runtime"
import "core:reflect"

destroy_owned :: proc(ptr: rawptr, ti: ^runtime.Type_Info) {
	ti := runtime.type_info_base(ti)
	#partial switch v in ti.variant {
	case runtime.Type_Info_Struct:
		for i in 0..<int(v.field_count) {
			destroy_owned(rawptr(uintptr(ptr) + v.offsets[i]), v.types[i])
		}

	case runtime.Type_Info_Dynamic_Array:
		raw := (^runtime.Raw_Dynamic_Array)(ptr)
		for i in 0..<raw.len {
			destroy_owned(rawptr(uintptr(raw.data) + uintptr(i * v.elem_size)), v.elem)
		}
		if raw.data != nil {
			runtime.mem_free(raw.data, raw.allocator)
		}

	case runtime.Type_Info_String:
		if v.is_cstring {
			s := (^cstring)(ptr)^
			if s != nil {
				runtime.mem_free(rawptr(s))
			}
		} else {
			s := (^runtime.Raw_String)(ptr)
			if s.data != nil {
				runtime.mem_free(s.data)
			}
		}

	case runtime.Type_Info_Map:
		raw := (^runtime.Raw_Map)(ptr)
		if raw.data == 0 {
			return
		}

		it := 0
		for {
			key, value, ok := reflect.iterate_map(any{ptr, ti.id}, &it)
			if !ok { break }
			destroy_owned(key.data, v.key)
			destroy_owned(value.data, v.value)
		}
		_ = runtime.map_free_dynamic(raw^, v.map_info)
	}
}
