package sprouts
import"core:sort"
import"core:slice"

Signature:: [dynamic]typeid;

deduped::#force_inline proc(sig:^Signature){
	slice.sort_by(sig[:],proc(a,b:typeid)->bool{
		return transmute(uintptr)a<transmute(uintptr)b
	})
	tmp:=slice.unique(sig[:])
	tmplen:=len(tmp)
	resize(sig,tmplen)
}
contains_type::#force_inline proc(sig:[]typeid,type:typeid)->bool{
	return slice.contains(sig[:],type)
}
make_signature::proc(types:..typeid,allocator:=context.allocator)->Signature{
	sig:=make(Signature,len(types),allocator)
	append(&sig,..types)
	deduped(&sig)
	return sig
}
signature_hash::proc(sig:[]typeid)->uintptr{
	h:uintptr = 1469598103934665603
	for id in sig{
		h~= transmute(uintptr)id+0x9e3779b97f4a7c15+(h<<6)+(h>>2)

	}
	return h
}
