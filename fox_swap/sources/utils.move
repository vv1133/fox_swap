/// Module: utils
module fox_swap::utils {
    public fun split_u64_into_u8s(value: u64): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut temp = value;
        let mut i = 0;
        while (i < 8) {
            bytes.push_back(((temp & 255) as u8));
            temp = temp >> 8;
            i = i + 1;
        };
        bytes
    }
}


