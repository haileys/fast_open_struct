#include <ruby.h>
#include "khash.h"

KHASH_MAP_INIT_INT(id, uint32_t)

struct open_struct {
	khash_t(id) *keys;
	VALUE values;
};

#define MAPPING_MASK (1 << 31)

static void rb_lstruct_mark(struct open_struct *os)
{
	rb_gc_mark(os->values);
}

static void rb_lstruct_free(struct open_struct *os)
{
	kh_destroy(id, os->keys);
	xfree(os);
}

static int store_new_key(
	struct open_struct *os, ID setter_id, VALUE value)
{
	const char *setter_name = rb_id2name(setter_id);
	size_t len = strlen(setter_name);
	char *getter_name = NULL;

	khiter_t pos; int ret;
	uint32_t value_pos;

	if (setter_name[len - 1] != '=')
		return -1;

	rb_ary_push(os->values, value);
	value_pos = RARRAY_LEN(os->values) - 1;

	getter_name = alloca(len);
	memcpy(getter_name, setter_name, len - 1);
	getter_name[len - 1] = '\0';

	pos = kh_put(id, os->keys, rb_intern(getter_name), &ret);
	kh_value(os->keys, pos) = value_pos;

	pos = kh_put(id, os->keys, setter_id, &ret);
	kh_value(os->keys, pos) = value_pos | MAPPING_MASK;

	return 0;
}

static int _load_default_key(VALUE key, VALUE value, struct open_struct *os)
{
	ID getter_id;
	const char *getter_name; 
	size_t len;
	char *setter_name = NULL;

	khiter_t pos; int ret;
	uint32_t value_pos;

	getter_id = (TYPE(key) == T_SYMBOL) ? SYM2ID(key) : rb_intern_str(key);
	getter_name = rb_id2name(getter_id);
	len = strlen(getter_name);

	rb_ary_push(os->values, value);
	value_pos = RARRAY_LEN(os->values) - 1;

	setter_name = alloca(len + 2);
	memcpy(setter_name, getter_name, len);
	setter_name[len] = '=';
	setter_name[len + 1] = '\0';

	pos = kh_put(id, os->keys, rb_intern(setter_name), &ret);
	kh_value(os->keys, pos) = value_pos | MAPPING_MASK;

	pos = kh_put(id, os->keys, getter_id, &ret);
	kh_value(os->keys, pos) = value_pos;

	return ST_CONTINUE;
}

static VALUE rb_lstruct_alloc(int argc, VALUE *argv, VALUE klass)
{
	struct open_struct *os;

	os = xmalloc(sizeof(struct open_struct));
	os->keys = kh_init(id);
	os->values = rb_ary_new();

	if (argc > 0) {
		VALUE hash = argv[0];

		if (TYPE(hash) != T_HASH)
			hash = rb_funcall(hash, rb_intern("to_h"), 0);

		rb_hash_foreach(hash, &_load_default_key, (VALUE)os);
	}

	return Data_Wrap_Struct(klass, &rb_lstruct_mark, &rb_lstruct_free, os);
}

static VALUE rb_lstruct_hook(int argc, VALUE *argv, VALUE self)
{
	struct open_struct *os = NULL;
	khiter_t pos;
	ID method = SYM2ID(argv[0]);

	Data_Get_Struct(self, struct open_struct, os);

	if (argc > 2)
		goto super;

	pos = kh_get(id, os->keys, method);

	if (pos == kh_end(os->keys)) {
		 if (argc == 1 || store_new_key(os, method, argv[1]) < 0)
			 goto super;

		 return argv[1];
	} else {
		uint32_t method_mapping = kh_value(os->keys, pos);
		uint32_t value_pos = method_mapping & ~MAPPING_MASK;

		if (method_mapping == value_pos) {
			return rb_ary_entry(os->values, value_pos);
		} else {
			 if (argc == 1)
				 goto super;

			rb_ary_store(os->values, value_pos, argv[1]);
			return argv[1];
		}
	}

super:
	return rb_call_super(argc, argv);
}

static VALUE rb_lstruct_respond(int argc, VALUE *argv, VALUE self)
{
	struct open_struct *os = NULL;

	Data_Get_Struct(self, struct open_struct, os);

	if (argc == 1) {
		khiter_t pos = kh_get(id, os->keys, SYM2ID(argv[0]));

		if (pos != kh_end(os->keys))
			return Qtrue;
	}

	return rb_call_super(argc, argv);
}

static VALUE rb_lstruct_get(VALUE self, VALUE key)
{
	struct open_struct *os = NULL;
	khiter_t pos;
	ID key_id;

	Data_Get_Struct(self, struct open_struct, os);
	key_id = (TYPE(key) == T_SYMBOL) ? SYM2ID(key) : rb_intern_str(key);

	if ((pos = kh_get(id, os->keys, key_id)) == kh_end(os->keys))
		return Qnil;

	return rb_ary_entry(os->values, kh_value(os->keys, pos) & ~MAPPING_MASK);
}

static VALUE rb_lstruct_set(VALUE self, VALUE key, VALUE val)
{
	struct open_struct *os = NULL;
	khiter_t pos;
	ID key_id;

	Data_Get_Struct(self, struct open_struct, os);

	key_id = (TYPE(key) == T_SYMBOL) ? SYM2ID(key) : rb_intern_str(key);
	pos = kh_get(id, os->keys, key_id);

	if (pos == kh_end(os->keys)) {
		_load_default_key(key, val, os);
	} else {
		rb_ary_store(os->values, kh_value(os->keys, pos) & ~MAPPING_MASK, val);
	}

	return val;
}

static VALUE rb_lstruct_each_pair(VALUE self)
{
	struct open_struct *os = NULL;
	ID key;
	uint32_t value_pos;

	if (!rb_block_given_p())
		return rb_funcall(self, rb_intern("to_enum"), 1, ID2SYM(rb_intern("each_pair")));

	Data_Get_Struct(self, struct open_struct, os);

	kh_foreach(os->keys, key, value_pos, {
		if ((value_pos & MAPPING_MASK) == 0)
			rb_yield_values(2, ID2SYM(key), rb_ary_entry(os->values, value_pos));
	});

	return Qnil;
}

static VALUE rb_lstruct_size(VALUE self)
{
	struct open_struct *os = NULL;
	Data_Get_Struct(self, struct open_struct, os);
	return INT2FIX(kh_size(os->keys) / 2);
}

void Init_fast_open_struct()
{
	VALUE rb_lstruct = rb_define_class("FastOpenStruct", rb_cObject);

	rb_define_method(rb_lstruct, "method_missing", rb_lstruct_hook, -1);
	rb_define_method(rb_lstruct, "respond_to?", rb_lstruct_respond, -1);
	rb_define_method(rb_lstruct, "[]", rb_lstruct_get, 1);
	rb_define_method(rb_lstruct, "[]=", rb_lstruct_set, 2);
	rb_define_method(rb_lstruct, "each_pair", rb_lstruct_each_pair, 0);
	rb_define_method(rb_lstruct, "size", rb_lstruct_size, 0);

	rb_define_singleton_method(rb_lstruct, "new", rb_lstruct_alloc, -1);
}
