// 导入网络请求
import ajax from "./request";
import { http } from "@kit.NetworkKit";

// 请求参数的类型约束
import {RegistrationInfo, SaveShopCartProduct} from "../model/other_t"

// Home页面的数据接口

// 拉取轮播图的接口
let fetchBanner = (): Promise<http.HttpResponse> => {
  // 发起网络请求
  return ajax("/banner")
}

// 拉取商品列表
let fetchHomeProductList = (): Promise<http.HttpResponse> =>{
  return ajax("/typeProducts", "GET", Object({
     key: "isHot",
     value: "1"
  }))
}

// 拉取商品分类
let fetchProductType = (): Promise<http.HttpResponse> =>{
  return ajax("/type", "GET")
}

/**
 * 通过分类拉取商品列表
 * @param value 要获取的商品的分类， 比如“latte”
 * @returns Promise<http.HttpResponse>
 */
let fetchProductListByType = (value:string):Promise<http.HttpResponse> =>{
  return ajax("/typeProducts", "GET", Object({
    key: "type",
    value
  }))
}


/**
 * 注册账号
 * @param registrationInfo 注册信息
 * @param registrationInfo.phone 手机号码
 * @param registrationInfo.password 密码
 * @param registrationInfo.nickName 昵称
 * @returns Promise<http.HttpResponse>
 */
let registerAccount = (registrationInfo: RegistrationInfo): Promise<http.HttpResponse> =>{
   return ajax("/register", "POST", registrationInfo)
}

/**
 * 登录账号
 * @param loginInfo 登录信息
 * @param loginInfo.phone 手机号码
 * @param loginInfo.password 密码
 * @returns Promise<http.HttpResponse>
 */
let loginAccount = (loginInfo: RegistrationInfo): Promise<http.HttpResponse> =>{
  return ajax("/login", "POST", loginInfo)
}

/**
 * 通过商品id 拉取 商品详情
 * @param pid
 * @returns
 */
let fetchProductDetailByPid = (pid:string): Promise<http.HttpResponse> =>{
    return ajax("/productDetail", "GET", Object({ pid: pid }))
}


/**
 * 查询商品是否被收藏
 * @param pid 商品id
 * @param token 用户登录token
 * @returns
 */
let fetchFavoriteStatus = (pid:string, token:string): Promise<http.HttpResponse> =>{
  return ajax("/findlike", "GET", Object({ pid: pid, tokenString: token }))
}

/**
 * 切换收藏状态的方法
 * @param pid 商品id
 * @param token 用户登录token
 * @param current_state 当前商品的收藏状态，  true当前收藏  false当前未收藏
 * @returns
 */
let toggleFavoriteStatus = (pid:string, token:string, current_state:boolean): Promise<http.HttpResponse> =>{
  // 根据收藏状态决定调用哪个接口   true当前收藏则取消收藏， false当前未收藏则收藏
  let url = current_state ? "/notlike" : "/like";
  return ajax(url, "POST", Object({ pid: pid, tokenString: token }))
}

/**
 * 添加商品到购物车的接口
 * @param saveShopCartProduct
 * @param saveShopCartProduct.pid    要添加到购物车的商品id
 * @param saveShopCartProduct.count  商品数量
 * @param saveShopCartProduct.rule   商品规格， 如 "冰/全糖/无奶油"
 * @param saveShopCartProduct.tokenString  用户登录的tokne
 * @returns 添加到购物车的状态
 */
let saveToShopCart = (saveShopCartProduct: SaveShopCartProduct ): Promise<http.HttpResponse> => {
  return ajax("/addShopcart", "POST", saveShopCartProduct);
}

/**
 * 拉取购物车所有商品的总数量
 * @param token 用户token
 * @returns
 */
let fetchShopCartCount = (token:string): Promise<http.HttpResponse> => {
  return ajax( "/shopcartCount", "GET", Object({ tokenString: token }) );
}

/**
 * 查询用户购物车所有商品记录条数  （有几条商品记录,   比如两条商品记录，但是有5件商品）
 * @param token 用户token
 * @returns
 */
let fetchAllShopcart = (token:string): Promise<http.HttpResponse> => {
  return ajax( "/findAllShopcart", "GET", Object({ tokenString: token }) );
}


// 导出数据接口
export {
  registerAccount // 注册接口
  ,loginAccount // 登录接口
  ,fetchBanner  // 拉取轮播图的接口
  ,fetchHomeProductList // 拉取商品列表
  ,fetchProductType // 拉取商品分类
  ,fetchProductListByType // 通过分类拉取商品列表
  ,fetchProductDetailByPid  // 通过商品id 拉取 商品详情
  ,fetchFavoriteStatus // 拉取商品的收藏状态
  ,toggleFavoriteStatus // 切换收藏状态的方法
  ,saveToShopCart // 保存商品到购物车的方法
  ,fetchShopCartCount // 拉取购物车所有商品的总数量
  ,fetchAllShopcart // 查询用户购物车所有商品记录条数
}