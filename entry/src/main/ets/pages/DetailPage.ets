// 导入数据接口
import { fetchProductDetailByPid, fetchFavoriteStatus, toggleFavoriteStatus, saveToShopCart, fetchShopCartCount } from '../api/api';
// 导入数据类型约束
import { product_detail_t, product_detail_item_t } from "../model/request";
import { RuleOption, RuleOptionItem, UserLoginToken, SaveShopCartProduct } from "../model/other_t";

// 数据持久化
import { PersistenceV2, Type, ConnectOptions, router, promptAction } from '@kit.ArkUI';


const APP_KEY: string = 'U2FsdGVkX19WSQ59Cg+Fj9jNZPxRC5y0xB1iV06BeNA=';
const BASE_URL: string = 'https://kf.webxyq.com';
const TOKEN_KEY: string = 'account_token';


@Entry
@ComponentV2
struct DetailPage {
  // key不传入尝试用为type的name作为key，加密参数不传入默认加密等级为EL2
  @Local p: UserLoginToken =
    PersistenceV2.globalConnect(
      { type: UserLoginToken, key: "account_token", defaultCreator: () => new UserLoginToken() })!;
  // ProductDetailPage.ets
  // HarmonyOS Stage 模型商品详情页（1:1 复刻参考图设计）
  // pid 通过路由参数传递；商品图片使用粉色纯色盒子替代

  @Local pid: string = '' || "latte006";
  @Local product: product_detail_item_t | null = null;
  @Local isLoading: boolean = false; // 是否加载完成
  @Local isFavorite: boolean = false; // 判断商品是否被收藏
  @Local isFavOperating: boolean = false; // 切换收藏状态时 进行 函数防抖  =>  (防抖函数/节流函数)
  @Local isSaveToShopCarting: boolean = false; // 是否保存到购物车的过程中 进行 函数防抖  =>  (防抖函数/节流函数)
  @Local quantity: number = 1; // 要购买的商品数量
  @Local shop_cart_count: number = 0; // 购物袋中的商品数量

  // 可选规格
  private rule: string[] = ["tem", "milk", "sugar", "cream"];
  @Local rule_opt: RuleOption = {};
  private account_token: string = ''; // 用户登录状态 有token就有登录

  // 页面渲染前 触发的方法
  async aboutToAppear() {
    // 从路由参数获取 pid
    const params = router.getParams() as Record<string, string>;
    if (params && params.pid) {
      this.pid = params.pid;
    }
    // 获取登录状态
    this.account_token = this.p.token;
    // 拉取商品详情 + 收藏状态
    this.getProductDetail();


    this.findIsLike();
    this.getShopCartCount();
  }

  // 获取商品详情
  private getProductDetail() {
    // 调用数据接口 获取 商品详情
    fetchProductDetailByPid(this.pid)
      .then(res => {
        // 获取到商品详情
        let data: product_detail_t = res.result as product_detail_t;
        console.log("获取商品详情 =>", JSON.stringify(data));

        // 如果数据正常
        if (data.code === 600 && data.result) {
          // 商品详情的数据
          const r: product_detail_item_t = data.result[0]; // [ {} ]
          // 把获取到的商品详情赋值给状态变量
          this.product = r;

          // 构建商品规格  ["sugar", "tem", "milk","cream"] = { "sugar":{描述，数组，选中下标}, ... }
          for (let item of this.rule) {
            // 去空
            if (Object(r)[item]) {
              // 非空，初始化子对象
              // this.rule_opt.sugar = { }
              Object(this.rule_opt)[item] = {
                // 给属性赋值
                desc: Object(r)[item + "_desc"],
                select_idx: 0,
                arr: Object(r)[item].split("/"),
              }
            }
          }
          // 状态不会处理深层数据的监听，即对象中的属性发生变化，这个对象不会驱动视图更新
          let temp = JSON.stringify(this.rule_opt); // "{a:1, b:2}"
          this.rule_opt = JSON.parse(temp); // {a:1, b:2} 直接修改整个对象
          console.log("规格对象", JSON.stringify(this.rule_opt));
        }
      })


  }

  // 查询商品是否已收藏
  private findIsLike() {
    // 如果没有登录
    if (!this.account_token) {
      return;
    }
    // Promise风格 处理网络请求的promise回调
    fetchFavoriteStatus(this.pid, this.account_token)
      .then(res => {
        console.log("查看是否被收藏", JSON.stringify(res.result));
        // 如果 res.result.result.length 长度为0， 表示这个商品没有被收藏
        this.isFavorite = Boolean(Object(res.result).result.length);
      })

    // async/await风格 处理网络请求的promise回调
    // let res = await findIsLike(this.pid, this.account_token);
    // console.log("查看是否被收藏", JSON.stringify(res.result))
  }

  // 切换收藏状态
  private toggleFavorite() {
    // 如果没有登录
    if (!this.account_token) {
      promptAction.openToast({ message: '请先登录' });
      router.pushUrl({ url: "pages/LoginPage" })
      return;
    }
    // 已经在切换状态中，多次点击是不会触发的
    if (this.isFavOperating) {
      return;
    }
    // 当前正在切换状态中， 多次点击无效
    this.isFavOperating = true;

    // 调用数据接口 切换收藏
    toggleFavoriteStatus(this.pid, this.account_token, this.isFavorite)
      .then(res => {
        console.log("切换效果 =>", JSON.stringify(res.result));
        // 800已收藏   900已取消收藏
        if (Object(res.result).code == 800 || Object(res.result).code == 900) {
          // 已经收藏
          this.isFavorite = !this.isFavorite;
        }
      })
      .finally(() => {
        // 切换
        this.isFavOperating = false;
      })
  }

  // 加入购物袋
  private onAddToBag() {
    // 如果没有登录
    if (!this.account_token) {
      promptAction.openToast({ message: "请先登录" })
      router.pushUrl({ url: "pages/LoginPage" });
      return;
    }
    // 如果是在保存到购物车的过程中 多次点击 不会推入多次数据到服务器  避免网络问题导致重复提交
    if(this.isSaveToShopCarting) return;

    // 更新状态： 正在提交中
    this.isSaveToShopCarting = true;
    // 构建当前选择的商品的规格
    // 映射： 原数组.map( (item, index)=>{return T }) :  Array<T>
    // Object.keys(this.rule_opt) 由对象的key组成的数组
    let rule: string = Object.keys(this.rule_opt).map((item: string) => {
      let obj: RuleOptionItem = Object(this.rule_opt)[item];
      return obj.arr[obj.select_idx];
    }).join("/");

    // 构建请求参数
    let product_info: SaveShopCartProduct = {
      rule,
      pid: this.pid,
      count: this.quantity,
      tokenString: this.account_token
    }
    // console.log("要添加到购物车的商品数据 =>", JSON.stringify(product_info));

    // 调用保存到购物袋的方法
    saveToShopCart(product_info)
      .then(res => {
        console.log("添加到购物车的状态 =>", JSON.stringify(res.result));

        if (Object(res.result).code === 3000) {
          promptAction.openToast({ message: "加入购物车成功" })
          this.shop_cart_count += this.quantity;
        }
      })
      .finally(()=>{
        // 加入购物车结束，才可以触发下一次的提交
        this.isSaveToShopCarting = false;
      })
  }

  // 查看当前购物袋的商品总数量
  private getShopCartCount(){
    // 如果没有登录，看不到购物袋的商品
    if(!this.account_token) return;

    fetchShopCartCount(this.account_token)
      .then(res=>{
        // {"msg":"查询购物车数量成功","code":4000,"result":null}
        // {"msg":"查询购物车数量成功","code":4000,"result":9}

         if( Object(res.result).code === 4000 ){
           // 购物袋的商品总数量 赋值给 状态变量
           this.shop_cart_count = Object(res.result).result ?  Object(res.result).result : 0;
         }
      })
  }


  build() {
    Column() {
      // 顶部导航栏
      this.TopBar();

      // 可滚动内容区
      Scroll() {
        Column() {
          // 商品主图
          this.HeroImage();

          // 商品信息
          this.ProductInfo();

          // ["cream", "sugar", "tem"]
          ForEach(Object.keys(this.rule_opt), (item: string) => {
            // 温度选项（子组件调用，@Prop 自动同步 selectedTemp）
            OptionGroup({
              label: Object(this.rule_opt)[item].desc,
              options: Object(this.rule_opt)[item].arr,
              selected: Object(this.rule_opt)[item].select_idx,
              onSelect: (idx: number) => {
                // "this.selectedTemp" = v;
                Object(this.rule_opt)[item].select_idx = idx;

                // 状态不会处理深层数据的监听，即对象中的属性发生变化，这个对象不会驱动视图更新
                let temp = JSON.stringify(this.rule_opt); // "{a:1, b:2}"
                this.rule_opt = JSON.parse(temp); // {a:1, b:2} 直接修改整个对象
                console.log("规格对象", JSON.stringify(this.rule_opt));
              }
            });
          })


          // 数量选择
          this.QuantitySelector();

          // 商品描述
          this.ProductDesc();
        }
        .width('100%');
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      // 底部操作栏
      this.BottomBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }

  // ================= 自定义构建函数 =================

  // 顶部导航栏
  @Builder
  TopBar() {
    Row() {
      Text('< 返回')
        .fontSize(16)
        .fontColor('#333333')
        .onClick(() => {
          router.back(); // 返回上一页
        });

      Blank();

      Text('商品详情')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333');

      Blank();

      // 右侧占位保持标题居中
      Text('< 返回')
        .fontSize(16)
        .fontColor(Color.Transparent);
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF');
  }

  // 商品主图（粉色纯色盒子替代图片）
  @Builder
  HeroImage() {
    Stack() {
      // 粉色纯色盒子替代商品图片
      Image(this.product?.small_img)
        .width('100%')
        .height(320)
        .backgroundColor(Color.Pink)
        .borderRadius(0);

    }
    .width('100%')
    .height(320)
    .alignContent(Alignment.Center)
    .backgroundColor('#EEF2F7');
  }

  // 商品信息：名称 + 英文名 + 价格
  @Builder
  ProductInfo() {
    Row() {
      Column() {
        Text(this.product?.name)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333');

        Text(this.product?.enname)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Text(`¥${this.product?.price}`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#DC2626');
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 16,
      bottom: 16
    })
    .alignItems(VerticalAlign.Center);
  }

  // 数量选择器
  @Builder
  QuantitySelector() {
    Row() {
      Text('选择数量')
        .fontSize(14)
        .fontColor('#333333')
        .layoutWeight(1);

      // 减号
      Text('-')
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('#F3F4F6')
        .fontColor('#333333')
        .fontSize(18)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.quantity > 1) {
            this.quantity--;
          }
        });

      Text(this.quantity.toString())
        .width(48)
        .fontSize(16)
        .fontColor('#333333')
        .textAlign(TextAlign.Center);

      // 加号
      Text('+')
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('#F3F4F6')
        .fontColor('#333333')
        .fontSize(18)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          // if (this.quantity < 99) {
            this.quantity++;
          // }
        });
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8
    })
    .alignItems(VerticalAlign.Center);
  }

  // 商品描述
  @Builder
  ProductDesc() {
    Column() {
      Text('商品描述')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ bottom: 8 });

      Text(this.product?.desc && this.product?.desc.length > 0
        ? this.product?.desc
        : '1. 百香果的酸甜果香，清新怡人；\n2. 茉莉花茶底清香悠长，口感柔和；\n3. 椰果Q弹有嚼劲，层次丰富。')
        .fontSize(13)
        .fontColor('#666666')
        .lineHeight(22);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 16,
      right: 16,
      top: 16,
      bottom: 24
    });
  }

  // 底部操作栏
  @Builder
  BottomBar() {
    Row() {

      // 徽标
      Badge({
        count: this.shop_cart_count,
        style: {},
        position: BadgePosition.RightTop,
      }) {
        // 购物袋入口
        Column() {
          Text('🛍')
            .fontSize(22);
          Text('购物袋')
            .fontSize(11)
            .fontColor('#666666')
            .margin({ top: 2 });
        }.alignItems(HorizontalAlign.Center)
        .width(56)
      }
      .width(56)
      .onClick(() => {
        // 跳转购物袋
        router.pushUrl(
          {
            url:"pages/Index",
            params:{selectedIndex: 2} // 下标， 给 index页面的tab标签使用，让它可以精确跳转到购物袋页面 而不是 home页面
          })
      });

      // 收藏入口
      Column() {
        Text(this.isFavorite ? '♥' : '♡')
          .fontSize(22)
          .fontColor(this.isFavorite ? '#DC2626' : '#666666');
        Text(this.isFavorite ? '已收藏' : '收藏')
          .fontSize(11)
          .fontColor(this.isFavorite ? '#DC2626' : '#666666')
          .margin({ top: 2 });
      }
      .width(56)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        // 切换收藏状态
        this.toggleFavorite();
      });

      // 加入购物袋按钮
      Button('加入购物袋')
        .layoutWeight(1)
        .height(44)
        .backgroundColor('#2563EB')
        .fontColor('#FFFFFF')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .borderRadius(22)
        .margin({ left: 12 })
        .onClick(() => {
          this.onAddToBag(); // 添加到购物袋
        });
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: { top: '#F0F0F0' } });
  }
}

// ================= 选项组子组件（温度 / 糖度通用，可复用） =================
// 用 @Component + @Prop 替代原 @Builder：
// @Builder 的基础类型参数是值快照，父组件 @State 变化不会重新传入；
// @Prop 是单向数据绑定，父组件 @State 变化会自动同步到子组件并触发重渲染，高亮正确刷新。
@Component
struct OptionGroup {
  @Prop label: string;
  @Prop options: string[];
  @Prop selected: number;
  onSelect: (idx: number) => void = () => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontColor('#333333')
        .width(56);

      Row() {
        ForEach(this.options, (opt: string, idx: number) => {
          Text(opt)
            .fontSize(13)
            .fontColor(idx === this.selected ? '#FFFFFF' : '#666666')
            .backgroundColor(idx === this.selected ? '#2563EB' : '#F3F4F6')
            .borderRadius(16)
            .padding({
              left: 14,
              right: 14,
              top: 6,
              bottom: 6
            })
            .margin({ right: 8 })
            .onClick(() => {
              this.onSelect(idx);
            });
        }); // 用选项值作 key 即可，@Prop 变化已能触发重渲染
      }
      .layoutWeight(1);
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8
    })
    .alignItems(VerticalAlign.Center);
  }
}