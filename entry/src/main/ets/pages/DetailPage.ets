import http from '@ohos.net.http';

import promptAction from '@ohos.promptAction';

// 导入数据接口
import { fetchProductDetailByPid } from '../api/api';
// 导入数据类型约束
import { product_detail_t, product_detail_item_t } from "../model/request"
import { RuleOption } from "../model/other_t";

// 数据持久化
import { PersistenceV2, Type, ConnectOptions, router } from '@kit.ArkUI';
import { UserLoginToken } from './LoginPage';


const APP_KEY: string = 'U2FsdGVkX19WSQ59Cg+Fj9jNZPxRC5y0xB1iV06BeNA=';
const BASE_URL: string = 'https://kf.webxyq.com';
const TOKEN_KEY: string = 'tokenString';


@Entry
@ComponentV2
struct DetailPage {
  // key不传入尝试用为type的name作为key，加密参数不传入默认加密等级为EL2
  @Local p: UserLoginToken =
    PersistenceV2.globalConnect({ type: UserLoginToken, defaultCreator: () => new UserLoginToken() })!;
  // ProductDetailPage.ets
  // HarmonyOS Stage 模型商品详情页（1:1 复刻参考图设计）
  // pid 通过路由参数传递；商品图片使用粉色纯色盒子替代

  @Local pid: string = 'latte006';
  @Local product: product_detail_item_t | null = null;
  @Local isFavorite: boolean = false;
  @Local isLoading: boolean = false;
  @Local isFavOperating: boolean = false;
  @Local quantity: number = 1;
  @Local tokenString: string = '';
  // 可选规格
  private rule: string[] = ["tem", "milk", "sugar", "cream"];
  @Local rule_opt: RuleOption = {};

  async aboutToAppear() {
    // 从路由参数获取 pid
    const params = router.getParams() as Record<string, string>;
    if (params && params.pid) {
      this.pid = params.pid;
    }
    this.tokenString = await this.readToken();

    // 拉取商品详情 + 收藏状态
    await this.getProductDetail();

    await this.fetchFavoriteStatus();
  }

  // 读取本地 token（占位实现）
  private async readToken(): Promise<string> {
    try {
      const token = await this.p.token;
      return token as string;
    } catch (e) {
      return '';
    }
  }

  // 获取商品详情
  private getProductDetail(): void {
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

  // 查询是否已收藏
  private async fetchFavoriteStatus(): Promise<void> {
    if (!this.pid || !this.tokenString) {
      return;
    }
    const httpReq = http.createHttp();
    const url = `${BASE_URL}/findlike?appkey=${APP_KEY}&pid=${this.pid}&tokenString=${this.tokenString}`;
    try {
      const resp = await httpReq.request(url, { method: http.RequestMethod.GET });
      console.log("111 是否收藏", resp);
      return;

    } catch (e) {
      // 查询失败默认未收藏
    } finally {
      httpReq.destroy();
    }
  }

  // 切换收藏状态
  private async toggleFavorite(): Promise<void> {
    if (this.isFavOperating) {
      return;
    }
    if (!this.tokenString) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    if (!this.pid) {
      return;
    }
    this.isFavOperating = true;
    const httpReq = http.createHttp();
    const url = this.isFavorite ? `${BASE_URL}/notlike` : `${BASE_URL}/like`;
    try {
      const resp = await httpReq.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        extraData: `appkey=${APP_KEY}&pid=${this.pid}&tokenString=${this.tokenString}`
      });
      console.log("222 取消收藏", resp);
      return;

    } catch (e) {
      promptAction.showToast({ message: '网络异常' });
    } finally {
      httpReq.destroy();
      this.isFavOperating = false;
    }
  }

  // 加入购物袋
  private onAddToBag(): void {

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
          router.back();
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
          if (this.quantity < 99) {
            this.quantity++;
          }
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
      // 购物袋入口
      Column() {
        Text('🛍')
          .fontSize(22);
        Text('购物袋')
          .fontSize(11)
          .fontColor('#666666')
          .margin({ top: 2 });
      }
      .width(56)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        // 跳转购物袋
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
          this.onAddToBag();
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