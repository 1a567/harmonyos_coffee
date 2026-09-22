// 搜索页 —— 复刻验收图
// 数据源：先拉全部分类 type，再按 type 拉每个分类的商品，合并成"全部商品" + 本地 filter

import ajax from "../api/request"
import { home_product_item_t, home_product_t, side_menu_t, side_menu_item_t } from "../model/request"
import { router } from "@kit.ArkUI"
import preferences from '@ohos.data.preferences'

const HISTORY_KEY: string = 'search_history'

@Entry
@Component
struct SearchPage {
  // 搜索框里的文字
  @State keyword: string = '美式'
  // 原始商品列表（接口拉取的全部商品 = 所有 type 的并集）
  @State allProducts: home_product_item_t[] = []
  // 搜索结果（filtered）
  @State resultList: home_product_item_t[] = []
  // 搜索历史（存用户最近搜过的词）
  @State history: string[] = []

  // Search 组件 controller（用于清空）
  private searchController: SearchController = new SearchController()
  // preferences 实例（存历史）
  private pref: preferences.Preferences | null = null

  aboutToAppear(): void {
    this.loadHistory()
    this.fetchAllProducts()
  }

  /**
   * 拉取全部商品作为搜索数据源
   * 后端 /typeProducts 必须带 key/value 过滤，不带会 501
   * 所以策略：先拉所有 type，再按 type 拉每个分类的商品，合并
   */
  private fetchAllProducts(): void {
    ajax('/type', 'GET')
      .then(typeRes => {
        let typeData: side_menu_t = typeRes.result as side_menu_t
        let types: side_menu_item_t[] = typeData.result

        // 每个 type 发一个请求，并发拿结果
        let promises: Promise<home_product_item_t[]>[] = types.map((t: side_menu_item_t) => {
          return ajax('/typeProducts', 'GET', Object({
            key: 'type',
            value: t.type
          })).then(pRes => {
            let pData: home_product_t = pRes.result as home_product_t
            return pData.result
          })
        })

        // 全部 Promise 完成后，合并数组
        Promise.all(promises).then((arr: home_product_item_t[][]) => {
          let merged: home_product_item_t[] = []
          for (let i = 0; i < arr.length; i++) {
            merged = merged.concat(arr[i])
          }
          this.allProducts = merged
          this.doSearch(this.keyword)
        })
      })
  }

  /** 根据关键字本地 filter */
  private doSearch(kw: string): void {
    if (!kw || kw.trim().length === 0) {
      this.resultList = []
      return
    }
    const k: string = kw.trim().toLowerCase()
    this.resultList = this.allProducts.filter((p: home_product_item_t) =>
      p.name.toLowerCase().includes(k) ||
      p.enname.toLowerCase().includes(k) ||
      p.typeDesc.toLowerCase().includes(k)
    )
  }

  /** 回车/点搜索时：保存历史 */
  private onSubmit(): void {
    const kw: string = this.keyword.trim()
    if (!kw) return
    this.doSearch(kw)
    this.saveHistory(kw)
  }

  // ========== 搜索历史持久化（用 Preferences） ==========

  private async loadHistory(): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(getContext(), 'search_pref')
      const arr = this.pref.getSync(HISTORY_KEY, []) as string[]
      // Preferences 存数组有坑，可能是 JSON 字符串
      if (Array.isArray(arr)) {
        this.history = arr
      } else if (typeof arr === 'string') {
        this.history = JSON.parse(arr)
      }
    } catch (e) {
      console.warn('loadHistory error =>', JSON.stringify(e))
    }
  }

  private async saveHistory(kw: string): Promise<void> {
    // 去重：如果已有，先删掉
    let list: string[] = this.history.filter((h: string) => h !== kw)
    // 插到最前面，最多留 10 条
    list.unshift(kw)
    if (list.length > 10) list = list.slice(0, 10)
    this.history = list
    try {
      if (this.pref) {
        await this.pref.put(HISTORY_KEY, JSON.stringify(list))
        await this.pref.flush()
      }
    } catch (e) {
      console.warn('saveHistory error =>', JSON.stringify(e))
    }
  }

  private async clearAllHistory(): Promise<void> {
    this.history = []
    try {
      if (this.pref) {
        await this.pref.delete(HISTORY_KEY)
        await this.pref.flush()
      }
    } catch (e) {
      console.warn('clearHistory error =>', JSON.stringify(e))
    }
  }

  // ========== UI ==========

  build() {
    Column() {
      // 1. 顶部搜索栏
      this.TopSearchBar()

      // 2. 搜索历史（有历史才显示；搜索框为空或正在输入则显示）
      if (this.history.length > 0 && !this.keyword.trim()) {
        this.HistorySection()
      }

      // 3. 搜索结果区域
      if (this.keyword.trim()) {
        this.ResultSection()
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  // 顶部：返回 + 搜索框 + 取消
  @Builder
  TopSearchBar() {
    Row() {
      // 返回按钮
      Text('< 返回')
        .fontSize(16)
        .fontColor('#1A56DB')
        .onClick(() => {
          router.back()
        })

      // 搜索框（胶囊形状）
      Search({
        placeholder: '搜索咖啡、饮品',
        controller: this.searchController
      })
        .layoutWeight(1)
        .margin({ left: 12, right: 12 })
        .backgroundColor(Color.White)
        .borderRadius(20)
        .onChange((value: string) => {
          this.keyword = value
          // 输入过程中实时 filter
          this.doSearch(value)
        })
        .onSubmit(() => {
          this.onSubmit()
        })

      // 取消按钮（清空 + 回到历史页）
      Text('取消')
        .fontSize(16)
        .fontColor('#666666')
        .onClick(() => {
          this.keyword = ''
          this.resultList = []
          router.back()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  // 搜索历史区
  @Builder
  HistorySection() {
    Column() {
      Row() {
        Text('搜索历史')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Text('清除所有搜索历史')
          .fontSize(13)
          .fontColor('#999999')
          .onClick(() => {
            this.clearAllHistory()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      // 历史标签：圆角 pill + × 关闭
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.history, (kw: string, idx: number) => {
          Row() {
            Text(kw)
              .fontSize(14)
              .fontColor('#333333')

            Text('×')
              .fontSize(16)
              .fontColor('#999999')
              .margin({ left: 6 })
              .onClick(() => {
                this.removeHistoryItem(idx)
              })
          }
          .padding({ left: 14, right: 10, top: 8, bottom: 8 })
          .backgroundColor(Color.White)
          .borderRadius(18)
          .margin({ right: 10, bottom: 10 })
          .onClick(() => {
            // 点历史标签 → 填充搜索框 + 搜索
            this.keyword = kw
            this.doSearch(kw)
            this.saveHistory(kw)
          })
        }, (kw: string) => kw)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .margin({ top: 10 })
    .padding({ bottom: 16 })
  }

  private async removeHistoryItem(idx: number): Promise<void> {
    this.history.splice(idx, 1)
    try {
      if (this.pref) {
        await this.pref.put(HISTORY_KEY, JSON.stringify(this.history))
        await this.pref.flush()
      }
    } catch (e) { }
  }

  // 搜索结果区
  @Builder
  ResultSection() {
    if (this.resultList.length === 0) {
      // 空态
      Column() {
        Text('🔍')
          .fontSize(48)
        Text(`没有找到关于 "${this.keyword}" 的商品`)
          .fontSize(14)
          .fontColor('#8A8F99')
          .margin({ top: 12 })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      // 两列 Grid
      Grid() {
        ForEach(this.resultList, (item: home_product_item_t) => {
          GridItem() {
            this.ProductCard(item)
          }
        }, (item: home_product_item_t) => item.pid)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    }
  }

  // 商品卡片（复刻参考图：图 + 中文名 + 英文名(灰) + 红色价格）
  @Builder
  ProductCard(item: home_product_item_t) {
    Column() {
      // 商品图（1:1 比例）
      Image(item.smallImg)
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#EEEEEE')
        .borderRadius({ topLeft: 8, topRight: 8 })

      // 商品信息
      Column() {
        Text(item.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(item.enname)
          .fontSize(12)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })

        Text(`¥${item.price}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E02E24')
          .margin({ top: 6 })
          .width('100%')
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 10 })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { pid: item.pid } })
    })
  }
}
