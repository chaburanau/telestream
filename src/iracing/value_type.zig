pub const ValueType = enum(i32){
    CHAR(u8) = 0,
    BOOL(bool) = 1,
    INT(i32) = 2,
    BITS(u32) = 3,
    FLOAT(f32) = 4,
    DOUBLE(f64) = 5,
    UNKNOWN(()) = 6,
    IntVec(Vec<i32>) = 7,
    FloatVec(Vec<f32>) = 8,
    BoolVec(Vec<bool>) = 9,
};