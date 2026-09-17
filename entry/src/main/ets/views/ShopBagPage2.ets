// 导入数据接口
import { fetchAllShopcart } from "../api/api"
// 导入类型
import { UserLoginToken } from "../model/other_t"
import { find_all_shop_cart_t, find_all_shop_cart_item_t } from "../model/request"

import { PersistenceV2, router, promptAction } from "@kit.ArkUI";
import http from '@ohos.net.http';

// 删除购物车商品接口配置（逻辑删除/假删除）
const REMOVE_SHOPCART_URL: string = 'https://kf.webxyq.com/removeShopcart';
const APP_KEY: string = 'U2FsdGVkX19WSQ59Cg+Fj9jNZPxRC5y0xB1iV06BeNA=';

// ============================== 购物车包装模型（V2 状态管理） ==============================
// 接口类型 find_all_shop_cart_item_t 中没有 selected 字段、count 为接口原始数量，
// 这里用 @ObservedV2 包装类补充 UI 选中态与可变数量；
// @Trace 修饰的属性变化后，父页面 @Local 数组与子组件 @Param 都能自动刷新。
@ObservedV2
export class CartGoodsItem {
  // 接口原始商品数据（只读展示用：name/enname/rule 规格/price/small_img 等）
  goods: find_all_shop_cart_item_t;
  // 是否选中（左划列表/全选/合计都依赖它）
  @Trace selected: boolean = false;
  // 商品数量（步进器修改它，初始取接口 count）
  @Trace count: number = 1;

  constructor(goods: find_all_shop_cart_item_t, selected: boolean = false) {
    this.goods = goods;
    this.count = goods.count;
    this.selected = selected;
  }
}

// 构造一条符合接口类型约束的本地模拟商品（接口未联调时用于页面预览）
function makeMockGoods(sid: string, pid: string, name: string, enname: string,
  spec: string, price: string, count: number): find_all_shop_cart_item_t {
  return {
    count: count,
    created_at: '',
    desc: '',
    enname: enname,
    is_hot: 0,
    is_remove: 0,
    large_img: '',
    name: name,
    pid: pid,
    price: price,
    rule: spec,
    sid: sid,
    small_img: '',
    status: 1,
    type: '',
    type_desc: '',
    updated_at: '',
    user_id: ''
  };
}

// 自定义组件 -- ShopBag（购物袋）
@ComponentV2
  // export default  以默认导出的方式 导出组件
export default struct ShopBag {
  // 全局状态管理连接
  @Local p: UserLoginToken =
    PersistenceV2.globalConnect({ type: UserLoginToken, key: "account_token", defaultCreator: () => new UserLoginToken() })!;
  // 登录状态
  private token: string = "";
  // 接口原始购物车商品（保留，便于其他逻辑使用）
  @Local shop_cart_goods: find_all_shop_cart_item_t[] = [];
  // 页面渲染用的购物车列表（包装类，含选中态/可变数量）
  @Local cartList: CartGoodsItem[] = [
    new CartGoodsItem(makeMockGoods('s1001', '1001', '满杯百香果', 'Passion Fruit & Coconut Jelly Jasmin...', '冰/标准', '17.00', 1)),
    new CartGoodsItem(makeMockGoods('s1002', '1002', '黑糖拿铁', 'Brown Sugar Latte', '冷/半糖/无奶油', '28.00', 1)),
    new CartGoodsItem(makeMockGoods('s1003', '1003', '奥瑞白', 'Flat White', '热/单份糖', '28.00', 3)),
    new CartGoodsItem(makeMockGoods('s1004', '1004', '椰子冰', 'Coconut ice', '冰/无奶油', '20.00', 3))
  ];
  // 删除请求进行中标记，防止连续点击重复请求
  @Local isDeleting: boolean = false;
  // 是否处于编辑（批量删除）模式：右上角“编辑/完成”、底部“提交订单/删除选择”都由它驱动
  @Local isEditMode: boolean = false;

  // 生命周期 -- 页面渲染前
  aboutToAppear(): void {
    // 拿到登录状态
    this.token = this.p.token;
    // 查询购物车所有商品
    this.findAllShopCartProduct();
  }

  build() {
    Column() {
      // 顶部导航栏
      this.TopBar();

      // 广告 banner（pink 纯色盒子替代）
      this.Banner();

      // 商品列表（List 实现，ListItem 通过 swipeAction 支持左滑显示删除）
      List({ space: 12 }) {
        ForEach(this.cartList, (item: CartGoodsItem) => {
          ListItem() {
            CartItemCard({
              item: item,
              editMode: this.isEditMode,
              onSelect: (sid: string) => {
                this.toggleSelect(sid);
              },
              onStep: (sid: string, delta: number) => {
                this.stepQuantity(sid, delta);
              }
            });
          }
          .swipeAction({
            // end：左划后在 item 末尾（右侧）露出的操作区
            end: {
              builder: () => {
                this.DeleteButton(item.goods.sid);
              },
            },
            // 必须使用 SwipeEdgeEffect 枚举，不能写字符串 "spring"
            edgeEffect: SwipeEdgeEffect.Spring // 滑动效果
          });
        }, (item: CartGoodsItem) => item.goods.sid);
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .scrollBar(BarState.Off)
      .backgroundColor('#F5F6F8');

      // 底部结算栏（tabBar 按要求不实现）
      this.CheckoutBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .onVisibleAreaChange([0.0, 0.01, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible && currentRatio > 0) {
        // TODO..
        // this.refreshCart();   // 每次切到购物袋 tab：重新取 token + 拉最新购物车
      }
    });
  }

  // ============================== 数据请求 ==============================

  // 刷新购物车：重新读取最新 token 并拉取商品
  // 由 aboutToAppear（兜底）与 onVisibleAreaChange（tab 切换）共同调用
  private refreshCart(): void {
    // 每次都重新取 token：aboutToAppear 执行时可能尚未登录，切换回来时 token 已写入
    this.token = this.p.token;
    this.findAllShopCartProduct();
  }

  // 查询购物车所有商品
  private findAllShopCartProduct() {
    // 如果没有登录
    if (!this.token) return;

    // 拉取购物车的商品
    fetchAllShopcart(this.token)
      .then(res => {
        let data: find_all_shop_cart_t = res.result as find_all_shop_cart_t;
        // 如果查询成功 拿到购物车的所有商品，包装成带选中态的列表
        if (data.code === 5000) {
          this.shop_cart_goods = data.result;
          this.cartList = data.result.map((g: find_all_shop_cart_item_t) => new CartGoodsItem(g));
        }

        console.log("购物车商品 =>", JSON.stringify(this.shop_cart_goods))
      })
  }

  // ============================== 选中 / 全选 / 合计 ==============================

  // 全选状态：列表非空且每个商品都选中
  get allSelected(): boolean {
    return this.cartList.length > 0 && this.cartList.every((it: CartGoodsItem) => it.selected);
  }

  // 合计金额：仅统计选中商品（接口 price 为 string，需 Number 转换）
  get totalPrice(): number {
    let sum: number = 0;
    this.cartList.forEach((it: CartGoodsItem) => {
      if (it.selected) {
        sum += Number(it.goods.price) * it.count;
      }
    });
    return sum;
  }

  // 切换单个商品选中态（唯一入口，单选逻辑不写第二处；按购物车 sid 定位）
  private toggleSelect(sid: string): void {
    const target: CartGoodsItem | undefined =
      this.cartList.find((it: CartGoodsItem) => it.goods.sid === sid);
    if (target) {
      target.selected = !target.selected;
    }
  }

  // 全选 / 取消全选（唯一入口）
  private toggleSelectAll(): void {
    const target: boolean = !this.allSelected;
    this.cartList.forEach((it: CartGoodsItem) => {
      it.selected = target;
    });
  }

  // 数量增减（按购物车 sid 定位）
  private stepQuantity(sid: string, delta: number): void {
    const target: CartGoodsItem | undefined =
      this.cartList.find((it: CartGoodsItem) => it.goods.sid === sid);
    if (target) {
      const next: number = target.count + delta;
      if (next >= 1 && next <= 99) {
        target.count = next;
      }
    }
  }

  // 调用 removeShopcart 接口逻辑删除（支持单个或多个 sid）
  // 返回 true 表示后端删除成功，可同步移除本地列表
  private async removeShopcartApi(sids: string[]): Promise<boolean> {
    if (!this.token) {
      promptAction.showToast({ message: '请先登录' });
      return false;
    }
    if (sids.length === 0) return false;

    const httpRequest = http.createHttp();
    try {
      const resp = await httpRequest.request(REMOVE_SHOPCART_URL, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        // sids 必须是 JSON.stringify([sid1, sid2, sid3]) 形式的字符串
        extraData: `appkey=${APP_KEY}&tokenString=${this.token}&sids=${JSON.stringify(sids)}`
      });
      const data: Record<string, Object> = JSON.parse(resp.result as string);
      // 与查询接口保持一致：code === 7000 视为成功
      return Number(data.code) === 7000;
    } catch (e) {
      console.error('removeShopcart 请求异常 =>', JSON.stringify(e));
      return false;
    } finally {
      httpRequest.destroy();
    }
  }

  // 删除购物车商品（左滑删除按钮触发，按 sid 调接口）
  private async deleteItem(sid: string): Promise<void> {
    // 防抖：删除请求进行中忽略后续点击
    if (this.isDeleting) return;
    this.isDeleting = true;
    try {
      // 单个删除，sid 集合传一个元素的数组
      const ok: boolean = await this.removeShopcartApi([sid]);
      if (ok) {
        // 只有后端删除成功才移除本地 ListItem，保证前端与数据库一致
        this.cartList = this.cartList.filter((it: CartGoodsItem) => it.goods.sid !== sid);
        this.shop_cart_goods = this.shop_cart_goods.filter((g: find_all_shop_cart_item_t) => g.sid !== sid);
        promptAction.showToast({ message: '商品已删除' });
      } else {
        promptAction.showToast({ message: '删除失败，请稍后重试' });
      }
    } finally {
      this.isDeleting = false;
    }
  }

  // 提交订单
  private submitOrder(): void {
    const selectedCount: number = this.cartList
      .filter((it: CartGoodsItem) => it.selected)
      .reduce((acc: number, it: CartGoodsItem) => acc + it.count, 0);
    if (selectedCount === 0) {
      promptAction.showToast({ message: '请选择商品' });
      return;
    }
    promptAction.showToast({ message: `提交订单：共 ${selectedCount} 件，合计 ¥${this.totalPrice.toFixed(2)}` });
  }

  // 切换编辑模式：编辑 <-> 完成；切换时清空所有选中态，避免残留勾选影响下单合计
  private toggleEditMode(): void {
    this.isEditMode = !this.isEditMode;
    this.cartList.forEach((it: CartGoodsItem) => {
      it.selected = false;
    });
  }

  // 删除选中的商品（编辑模式下点击“删除选择”触发，sids = JSON.stringify([sid1, sid2, sid3])）
  private async deleteSelectedItems(): Promise<void> {
    if (this.isDeleting) return;
    // 收集被选中商品的购物车 sid 集合
    const selectedSids: string[] = this.cartList
      .filter((it: CartGoodsItem) => it.selected)
      .map((it: CartGoodsItem) => it.goods.sid);

    if (selectedSids.length === 0) {
      promptAction.showToast({ message: '请选择要删除的商品' });
      return;
    }

    this.isDeleting = true;
    try {
      // 一次请求批量逻辑删除，接口内部 sids 即 JSON.stringify([sid1, sid2, sid3])
      const ok: boolean = await this.removeShopcartApi(selectedSids);
      if (ok) {
        const sidSet: Set<string> = new Set<string>(selectedSids);
        // 后端删除成功后，本地列表同步移除
        this.cartList = this.cartList.filter((it: CartGoodsItem) => !sidSet.has(it.goods.sid));
        this.shop_cart_goods = this.shop_cart_goods.filter((g: find_all_shop_cart_item_t) => !sidSet.has(g.sid));
        promptAction.showToast({ message: `已删除 ${selectedSids.length} 件商品` });
      } else {
        promptAction.showToast({ message: '删除失败，请稍后重试' });
      }
    } finally {
      this.isDeleting = false;
    }
  }

  // ============================== 自定义构建函数 ==============================

  // 左滑露出的删除按钮（供 ListItem.swipeAction 的 end.builder 调用，sid 为购物车唯一标识）
  @Builder
  DeleteButton(sid: string) {
    Button('删除')
      .width(80)
      .height('100%')
      .backgroundColor('#F23030')
      .fontColor(Color.White)
      .fontSize(16)
      .borderRadius({ topLeft: 0, topRight: 12, bottomLeft: 0, bottomRight: 12 })
      .onClick(() => {
        this.deleteItem(sid);
      });
  }

  // 顶部导航栏：返回 / 购物袋 / 编辑
  @Builder
  TopBar() {
    Row() {
      Text('< 返回')
        .fontSize(16)
        .fontColor('#1A56DB')
        .onClick(() => {
          router.back();
        });

      Blank();

      Text('购物袋')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333');

      Blank();

      Text(this.isEditMode ? '完成' : '编辑')
        .fontSize(15)
        .fontColor('#1A56DB')
        .onClick(() => {
          // 编辑 <-> 完成：进入或退出批量删除模式
          this.toggleEditMode();
        });
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White);
  }

  // 顶部 banner（pink 纯色盒子 + 文案叠加）
  @Builder
  Banner() {
    Stack({ alignContent: Alignment.Start }) {
      // pink 纯色盒子替代 banner 图片
      Image("")
        .width('100%')
        .height(110)
        .backgroundColor(Color.Pink);

      Column() {
        Text('luckin coffee的新鲜')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White);
        Text('喝下第一口, 你就会懂')
          .fontSize(16)
          .fontColor(Color.White)
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20 });
    }
    .width('100%')
    .height(110);
  }

  // 底部结算栏：全选 / 合计 / 提交订单
  @Builder
  CheckoutBar() {
    Row() {
      // 全选圆圈：编辑模式选中为蓝色，普通模式选中为红色（与商品行圆圈一致）
      Stack() {
        Circle({ width: 20, height: 20 })
          .fill(this.allSelected ? (this.isEditMode ? '#2563EB' : '#F23030') : Color.White)
          .stroke(this.allSelected ? (this.isEditMode ? '#2563EB' : '#F23030') : '#CCCCCC')
          .strokeWidth(1.5);
        if (this.allSelected) {
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White);
        }
      }
      .width(28)
      .height(28)
      .margin({ right: 6 })
      .onClick(() => {
        this.toggleSelectAll();
      });

      Text('全选')
        .fontSize(15)
        .fontColor(this.allSelected ? (this.isEditMode ? '#2563EB' : '#F23030') : '#333333');

      Blank();

      if (this.isEditMode) {
        // 编辑模式：删除选择按钮（红橙渐变胶囊），批量逻辑删除选中商品
        Button('删除选择')
          .width(132)
          .height(44)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Color.Transparent)
          .linearGradient({
            angle: 90,
            colors: [['#F5222D', 0.0], ['#FF7A00', 1.0]]
          })
          .borderRadius(22)
          .opacity(this.isDeleting ? 0.6 : 1)
          .onClick(() => {
            this.deleteSelectedItems();
          });
      } else {
        // 普通模式：合计金额
        Row() {
          Text('合计: ')
            .fontSize(15)
            .fontColor('#333333');
          Text('¥')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E02E24');
          Text(this.totalPrice.toFixed(2))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E02E24');
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ right: 12 });

        // 提交订单按钮（红橙渐变胶囊）
        Button('提交订单')
          .width(132)
          .height(44)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Color.Transparent)
          .linearGradient({
            angle: 90,
            colors: [['#F5222D', 0.0], ['#FF7A00', 1.0]]
          })
          .borderRadius(22)
          .onClick(() => {
            this.submitOrder();
          });
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: { top: '#EEEEEE' } });
  }
}

// ============================== 单个购物车商品卡片（V2 子组件） ==============================
// V2 中不能再用 V1 的 @ObjectLink：
// 父组件传入 @ObservedV2 对象，子组件用 @Param 接收；
// 对象内 @Trace 属性（selected/count）变化时，子组件会自动刷新。
@ComponentV2
struct CartItemCard {
  @Require @Param item: CartGoodsItem;
  // 是否处于编辑模式：编辑模式选中圆圈为蓝色，普通模式为红色
  @Param editMode: boolean = false;
  @Event onSelect: (sid: string) => void = () => {};
  @Event onStep: (sid: string, delta: number) => void = () => {};

  build() {
    Row() {
      // 左侧选择圆圈
      Stack() {
        Circle({ width: 20, height: 20 })
          .fill(this.item.selected ? (this.editMode ? '#2563EB' : '#F23030') : Color.White)
          .stroke(this.item.selected ? (this.editMode ? '#2563EB' : '#F23030') : '#CCCCCC')
          .strokeWidth(1.5);
        if (this.item.selected) {
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White);
        }
      }
      .width(28)
      .height(28)
      .onClick(() => {
        this.onSelect(this.item.goods.sid);
      });

      // 商品图片（无图地址时呈现 pink 纯色盒子）
      Image(this.item.goods.small_img)
        .width(88)
        .height(88)
        .backgroundColor(Color.Pink)
        .borderRadius(8)
        .margin({ left: 2, right: 12 });

      // 商品信息
      Column() {
        // 名称 + 规格
        Row() {
          Text(this.item.goods.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          // 右侧显示商品规格（接口 rule 字段：如 冷/半糖/无奶油），不是商品名称
          Text(this.item.goods.rule)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%');

        // 英文名称
        Text(this.item.goods.enname)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');

        Blank();

        // 价格 + 数量步进器
        Row() {
          Text(`¥${this.item.goods.price}`)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E02E24')
            .layoutWeight(1);

          // 减号（红色描边圆）
          Stack() {
            Circle({ width: 26, height: 26 })
              .fill(Color.White)
              .stroke('#F23030')
              .strokeWidth(1.5);
            Text('−')
              .fontSize(16)
              .fontColor('#F23030');
          }
          .width(28)
          .height(28)
          .onClick(() => {
            this.onStep(this.item.goods.sid, -1);
          });

          Text(this.item.count.toString())
            .fontSize(16)
            .fontColor('#333333')
            .width(36)
            .textAlign(TextAlign.Center);

          // 加号（红色实心圆）
          Stack() {
            Circle({ width: 26, height: 26 })
              .fill('#F23030');
            Text('+')
              .fontSize(16)
              .fontColor(Color.White);
          }
          .width(28)
          .height(28)
          .onClick(() => {
            this.onStep(this.item.goods.sid, 1);
          });
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
      .layoutWeight(1)
      .height(88)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center);
  }
}
