// 输入框 自定义构建函数 所需要接收的参数类型
export interface input_field_t {
  label: string,  // 左侧的描述文本
  placeholder: string, // 右侧输入框的占位符
  text?: string,  // 输入框的值， 用来做手机号存储
  type: InputType, // 输入框的类型
  isValid: boolean, // 输入框的正则验证是否通过
  error: string, // 如果正则验证不通过， 提示的错误信息
  onChange: (value: string) => void, // 输入框的值发生变化时 触发的方法
}

// 注册信息
export interface RegistrationInfo {
  phone: string,
  password: string,
  nickName?:string
}

// 商品规格   Record<string, Object>
export interface RuleOption {
  tem?: RuleOptionItem
  milk?: RuleOptionItem
  sugar?: RuleOptionItem
  cream?: RuleOptionItem
}
export interface RuleOptionItem {
  desc: string,
  select_idx: number,
  arr: string[],
}

// 要持久化存储的登录状态
@ObservedV2
export class UserLoginToken {
  @Trace public token: string = "";
}

// 添加到购物车的商品数据
export interface SaveShopCartProduct {
  pid:string,
  count:number,
  rule:string,
  tokenString:string
}

