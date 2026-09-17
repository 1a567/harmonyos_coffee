
// 轮播图的数据类型约束
export interface banner_t {
    code: number;
    result: banner_item_t[];
}

export interface banner_item_t {
    bannerImg: string;
    name: string;
    pid: string;
}


// 首页商品列表类型约束
export interface home_product_t {
    code: number;
    result: home_product_item_t[];
}

export interface home_product_item_t {
    createdAt: string;
    desc: string;
    enname: string;
    id: number;
    isHot: number;
    largeImg: string;
    name: string;
    pid: string;
    price: string;
    smallImg: string;
    type: string;
    typeDesc: string;
    updatedAt: string;
}


export interface side_menu_t {
    code: number;
    result: side_menu_item_t[];
}

export interface side_menu_item_t {
    createdAt: string;
    id: number;
    type: string;
    typeDesc: string;
    updatedAt: string;
}


export interface product_detail_t {
    code: number;
    msg: string;
    result: product_detail_item_t[];
}

export interface product_detail_item_t {
    cream: string;
    cream_desc: string;
    desc: string;
    enname: string;
    is_hot: number;
    large_img: string;
    milk: string;
    milk_desc: string;
    name: string;
    pid: string;
    price: string;
    small_img: string;
    sugar: string;
    sugar_desc: string;
    tem: string;
    tem_desc: string;
    type: string;
    type_desc: string;
}


export interface find_all_shop_cart_t {
    code: number;
    msg: string;
    result: find_all_shop_cart_item_t[];
}

export interface find_all_shop_cart_item_t {
    count: number;
    created_at: string;
    desc: string;
    enname: string;
    is_hot: number;
    is_remove: number;
    large_img: string;
    name: string;
    pid: string;
    price: string;
    rule: string;
    sid: string;
    small_img: string;
    status: number;
    type: string;
    type_desc: string;
    updated_at: string;
    user_id: string;
}