// 导入数据接口
import { fetchAllShopcart } from "../api/api"
// 导入类型
import { UserLoginToken }from "../model/other_t"
import {find_all_shop_cart_t, find_all_shop_cart_item_t} from "../model/request"

import { PersistenceV2, router, promptAction } from "@kit.ArkUI";


// #if false  这里的代码要删除
// 购物车商品数据模型（@Observed：子组件可感知属性变化）
@Observed
class CartItem {
  pid: string;
  name: string;
  ename: string;
  spec: string;
  price: number;
  quantity: number;
  selected: boolean;

  constructor(pid: string, name: string, ename: string, spec: string,
    price: number, quantity: number, selected: boolean = false) {
    this.pid = pid;
    this.name = name;
    this.ename = ename;
    this.spec = spec;
    this.price = price;
    this.quantity = quantity;
    this.selected = selected;
  }
}
// #endif


// 自定义组件 -- MenuPage
@ComponentV2
// export default  以默认导出的方式 导出组件
export default struct ShopBag {
  // 全局状态管理连接
  @Local p: UserLoginToken =
    PersistenceV2.globalConnect({ type: UserLoginToken, key:"account_token", defaultCreator: () => new UserLoginToken() })!;
  // 登录状态
  private token:string = "";
  // 购物车的商品
  @Local shop_cart_goods: find_all_shop_cart_item_t[] = [];

  // 生命周期 -- 页面渲染前
  aboutToAppear(): void {
    // 拿到登录状态
    this.token = this.p.token;
    // // 查询购物车所有商品
    // this.findAllShopCartProduct();
  }

  build(){
    Column() {
      // 顶部导航栏
      this.TopBar();

      // 广告 banner（pink 纯色盒子替代）
      this.Banner();

      // 商品列表（List 实现，ListItem 通过 swipeAction 支持左滑显示删除）
      List({ space: 12 }) {
        ForEach(this.items, (item: CartItem) => {
          ListItem() {
            CartItemCard({
              item: item,
              onSelect: (pid: string) => {
                this.toggleSelect(pid);
              },
              onStep: (pid: string, delta: number) => {
                this.stepQuantity(pid, delta);
              }
            });
          }
          .swipeAction({
            // end：左划后在 item 末尾（右侧）露出的操作区
            end: {
              builder: () => {
                this.DeleteButton(item.pid);
              },
            },
            // 必须使用 SwipeEdgeEffect 枚举，不能写字符串 "spring"
            edgeEffect: SwipeEdgeEffect.Spring // 滑动效果
          });
        }, (item: CartItem) => item.pid);
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
    .backgroundColor('#F5F6F8');
  }



  // 查询购物车所有商品
  private findAllShopCartProduct(){
    // 如果没有登录
    if(!this.token) return;

    // 拉取购物车的商品
    fetchAllShopcart(this.token)
      .then( res=>{
        let data: find_all_shop_cart_t = res.result as find_all_shop_cart_t;
        // 如果查询成功 拿到购物车的所有商品
        if(data.code === 5000)  this.shop_cart_goods = data.result;

        console.log("购物车商品 =>", JSON.stringify( this.shop_cart_goods ))
      })
  }

  @Local items: CartItem[] = [
    new CartItem('1001', '满杯百香果', 'Passion Fruit & Coconut Jelly Jasmin...', '冰/标准', 17.00, 1),
    new CartItem('1002', '黑糖拿铁', 'Brown Sugar Latte', '冷/半糖/无奶油', 28.00, 1),
    new CartItem('1003', '奥瑞白', 'Flat White', '热/单份糖', 28.00, 3),
    new CartItem('1004', '椰子冰', 'Coconut ice', '冰/无奶油', 20.00, 3)
  ];
  @Local isEditMode: boolean = false;

  // 全选状态：所有商品均选中
  get allSelected(): boolean {
    return this.items.length > 0 && this.items.every((it: CartItem) => it.selected);
  }

  // 合计金额：仅统计选中商品
  get totalPrice(): number {
    let sum: number = 0;
    this.items.forEach((it: CartItem) => {
      if (it.selected) {
        sum += it.price * it.quantity;
      }
    });
    return sum;
  }

  // 切换单个商品选中态
  private toggleSelect(pid: string): void {
    this.items.forEach((it: CartItem) => {
      if (it.pid === pid) {
        it.selected = !it.selected;
      }
    });
  }

  // 全选 / 取消全选
  private toggleSelectAll(): void {
    const target: boolean = !this.allSelected;
    this.items.forEach((it: CartItem) => {
      it.selected = target;
    });
  }

  // 数量增减
  private stepQuantity(pid: string, delta: number): void {
    this.items.forEach((it: CartItem) => {
      if (it.pid === pid) {
        const next: number = it.quantity + delta;
        if (next >= 1 && next <= 99) {
          it.quantity = next;
        }
      }
    });
  }

  // 删除购物车商品（左滑删除按钮触发）
  private deleteItem(pid: string): void {
    // 重新赋值数组，ForEach 通过 pid 做 key 差分时会移除对应 ListItem
    this.items = this.items.filter((it: CartItem) => it.pid !== pid);
    promptAction.showToast({ message: '商品已删除' });
  }

  // 提交订单
  private submitOrder(): void {
    const selectedCount: number = this.items
      .filter((it: CartItem) => it.selected)
      .reduce((acc: number, it: CartItem) => acc + it.quantity, 0);
    if (selectedCount === 0) {
      promptAction.showToast({ message: '请选择商品' });
      return;
    }
    promptAction.showToast({ message: `提交订单：共 ${selectedCount} 件，合计 ¥${this.totalPrice.toFixed(2)}` });
  }


  // 左滑露出的删除按钮（供 ListItem.swipeAction 的 end.builder 调用）
  @Builder
  DeleteButton(pid: string) {
    Button('删除')
      .width(80)
      .height('100%')
      .backgroundColor('#F23030')
      .fontColor(Color.White)
      .fontSize(16)
      .borderRadius({ topLeft: 0, topRight: 12, bottomLeft: 0, bottomRight: 12 })
      .onClick(() => {
        this.deleteItem(pid);
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
          this.isEditMode = !this.isEditMode;
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
      // 全选圆圈
      Stack() {
        Circle({ width: 20, height: 20 })
          .fill(this.allSelected ? '#F23030' : Color.White)
          .stroke(this.allSelected ? '#F23030' : '#CCCCCC')
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
        .fontColor('#333333');

      Blank();

      // 合计
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
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: { top: '#EEEEEE' } });
  }

}


// 单个购物车商品卡片（@ObjectLink 与父组件 @State 数组项双向同步）
@Component
struct CartItemCard {
  @ObjectLink item: CartItem;
  onSelect: (pid: string) => void = () => {};
  onStep: (pid: string, delta: number) => void = () => {};

  build() {
    Row() {
      // 左侧选择圆圈
      Stack() {
        Circle({ width: 20, height: 20 })
          .fill(this.item.selected ? '#F23030' : Color.White)
          .stroke(this.item.selected ? '#F23030' : '#CCCCCC')
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
        this.onSelect(this.item.pid);
      });

      // 商品图片（pink 纯色盒子替代）
      Image("")
        .width(88)
        .height(88)
        .backgroundColor(Color.Pink)
        .borderRadius(8)
        .margin({ left: 2, right: 12 });

      // 商品信息
      Column() {
        // 名称 + 规格
        Row() {
          Text(this.item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text(this.item.spec)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%');

        // 英文名称
        Text(this.item.ename)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');

        Blank();

        // 价格 + 数量步进器
        Row() {
          Text(`¥${this.item.price.toFixed(2)}`)
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
            this.onStep(this.item.pid, -1);
          });

          Text(this.item.quantity.toString())
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
            this.onStep(this.item.pid, 1);
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


/* ==================================  */

// ShoppingBagPage.ets
// HarmonyOS Stage 模型购物袋页面（1:1 复刻参考图设计）
// 所有图片（banner、商品图）使用 pink 纯色盒子替代；底部 tabBar 按要求不实现
