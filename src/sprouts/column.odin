package sprouts

import "base:runtime"
import "core:mem"
Column::struct{
	info:^Component_Info,
	data:^u8,
	count:uint,
	capacity:uint,
	allocator:mem.Allocator
}
column_init::proc(new_info:^Component_Info,new_allocator:=context.allocator)-> Column{
	return Column{info=new_info,allocator =new_allocator}
}
column_ensure_capacity::proc(col:^Column,needed:uint){
	if needed<= col.capacity {return}
	new_cap:= col.capacity*2 if col.capacity!=0 else 8
	if new_cap<needed{new_cap=needed}
	fresh,err:=runtime.mem_alloc(int(new_cap)*col.info.size,col.info.align,col.allocator)
	assert(err==nil)
	if col.data !=nil{
		runtime.mem_copy_non_overlapping(raw_data(fresh),col.data,int(col.count)*col.info.size)
		column_release(col)
	}
	col.data=raw_data(fresh)
	col.capacity=new_cap
}
column_release::proc(col:^Column){
	if col.data!=nil{
		mem.free(col.data,col.allocator)
	}
}
column_destroy_all::proc(col:^Column){
	if col.info.size ==0|| col.info.destroy==nil{return}
	for i in 0..<col.count{
		col.info.destroy(column_at(col,i))
	}
}
column_slot::proc(col:^Column,index:uint)->rawptr{

	return rawptr(uintptr(col.data)+uintptr(index)*uintptr(col.info.size))
}
@(private)
column_at::proc(col:^Column,index:uint)-> rawptr{
	assert(col.count>index)
	return column_slot(col,index)
}
column_push_empty::proc(col:^Column){
	if(col.info.size!=0){
		column_ensure_capacity(col,col.count+1)
		mem.zero(column_at(col,col.count),col.info.size)
	}
	col.count+=1
}
column_push_move::proc(col:^Column,src:rawptr){
	if(col.info.size!=0){
		column_ensure_capacity(col,col.count+1)
		mem.copy_non_overlapping(column_at(col,col.count),src,col.info.size)
		mem.zero(src,col.info.size)	
	}
	col.count+=1
	
}
column_swap_remove :: proc(col: ^Column, index: uint) {
	assert(index < col.count)
	last := col.count - 1
	if col.info.size != 0 {
		dst := column_slot(col, index)
		if col.info.destroy != nil {
			col.info.destroy(dst)
		}
		if index != last {
			src := column_slot(col, last)
			mem.copy_non_overlapping(dst, src, col.info.size)
			mem.zero(src, col.info.size)
		}
	}
	col.count -= 1
}
