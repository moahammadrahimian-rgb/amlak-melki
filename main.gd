extends Control

const API_BASE := "http://10.0.2.2:3000/api"
var token := ""
var user := {}
var http := HTTPRequest.new()
var content: VBoxContainer
var status: Label
var current_query := ""

func _ready():
    add_child(http)
    http.request_completed.connect(_on_http)
    _ui()
    _load()

func _ui():
    var bg=ColorRect.new(); bg.color=Color("#f5f7fb"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
    var scroll=ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_left=20; scroll.offset_top=20; scroll.offset_right=-20; scroll.offset_bottom=-20; add_child(scroll)
    content=VBoxContainer.new(); content.add_theme_constant_override("separation",12); scroll.add_child(content)
    var title=Label.new(); title.text="🏠 املاک ملکی"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; title.add_theme_font_size_override("font_size",34); content.add_child(title)
    var sub=Label.new(); sub.text="خرید • فروش • رهن • اجاره"; sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; content.add_child(sub)

    var auth=Button.new(); auth.text="ورود / ثبت‌نام"; auth.custom_minimum_size.y=60; auth.pressed.connect(_auth); content.add_child(auth)
    var profile=Button.new(); profile.text="پروفایل من"; profile.custom_minimum_size.y=55; profile.pressed.connect(_profile); content.add_child(profile)
    var add=Button.new(); add.text="➕ ثبت آگهی جدید"; add.custom_minimum_size.y=60; add.pressed.connect(_add); content.add_child(add)

    var search=LineEdit.new(); search.name="Search"; search.placeholder_text="جستجو شهر، محله، عنوان..."; search.alignment=HORIZONTAL_ALIGNMENT_RIGHT; search.custom_minimum_size.y=60; content.add_child(search)
    var filters=HBoxContainer.new()
    var buy=Button.new(); buy.text="فروش"; buy.pressed.connect(func(): search.text="فروش"; _load("فروش")); filters.add_child(buy)
    var rent=Button.new(); rent.text="اجاره"; rent.pressed.connect(func(): search.text="اجاره"; _load("اجاره")); filters.add_child(rent)
    var all=Button.new(); all.text="همه"; all.pressed.connect(func(): search.text=""; _load("")); filters.add_child(all)
    content.add_child(filters)
    var sb=Button.new(); sb.text="🔎 جستجوی آنلاین"; sb.custom_minimum_size.y=58; sb.pressed.connect(func(): _load(search.text)); content.add_child(sb)
    status=Label.new(); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; content.add_child(status)
    var sep=HSeparator.new(); content.add_child(sep)
    var h=Label.new(); h.text="آگهی‌های تأییدشده"; h.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; h.add_theme_font_size_override("font_size",24); content.add_child(h)

func _clear_cards():
    for c in content.get_children():
        if c.has_meta("card"): c.queue_free()

func _load(q=""):
    current_query=q; status.text="در حال دریافت..."
    var url=API_BASE+"/properties"
    if q!="": url+="?q="+q.uri_encode()
    http.request(url,["Accept: application/json"])

func _on_http(result,code,headers,body):
    if code<200 or code>=300: status.text="اتصال برقرار نشد: "+str(code); return
    var d=JSON.parse_string(body.get_string_from_utf8())
    if typeof(d)!=TYPE_DICTIONARY: return
    if d.has("token"): token=d.token
    if d.has("user"): user=d.user
    if d.has("properties"): _render(d.properties); status.text="تعداد آگهی: "+str(d.properties.size())

func _render(arr):
    _clear_cards()
    for p in arr:
        var card=VBoxContainer.new(); card.set_meta("card",true); card.add_theme_constant_override("separation",5)
        var t=Label.new(); t.text=str(p.get("title","")); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; t.add_theme_font_size_override("font_size",21); card.add_child(t)
        var info=Label.new(); info.text="%s | %s | %s تومان | %s متر" % [p.get("city",""),p.get("type",""),p.get("price",""),p.get("area","")]; info.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; card.add_child(info)
        var b=Button.new(); b.text="مشاهده جزئیات"; b.pressed.connect(func(): _detail(p)); card.add_child(b)
        content.add_child(card)

func _auth():
    var d=AcceptDialog.new(); d.title="ورود / ثبت‌نام"
    var box=VBoxContainer.new()
    var email=LineEdit.new(); email.placeholder_text="ایمیل"; box.add_child(email)
    var pass=LineEdit.new(); pass.placeholder_text="رمز عبور (حداقل ۶ کاراکتر)"; pass.secret=true; box.add_child(pass)
    var name=LineEdit.new(); name.placeholder_text="نام (برای ثبت‌نام)"; box.add_child(name)
    var phone=LineEdit.new(); phone.placeholder_text="شماره تماس"; box.add_child(phone)
    var login=Button.new(); login.text="ورود"; login.pressed.connect(func(): _auth_post("/auth/login",{"email":email.text,"password":pass.text},d)); box.add_child(login)
    var reg=Button.new(); reg.text="ثبت‌نام"; reg.pressed.connect(func(): _auth_post("/auth/register",{"name":name.text,"email":email.text,"password":pass.text,"phone":phone.text},d)); box.add_child(reg)
    d.add_child(box); add_child(d); d.popup_centered_ratio(0.8)

func _auth_post(path, data, d):
    http.request(API_BASE+path,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(data))
    d.queue_free()

func _profile():
    var d=AcceptDialog.new(); d.title="پروفایل"
    d.dialog_text = ("وارد نشده‌اید." if token=="" else "نام: %s\nایمیل: %s\nشماره: %s" % [user.get("name",""),user.get("email",""),user.get("phone","")])
    add_child(d); d.popup_centered()

func _add():
    if token=="":
        _auth(); return
    var d=AcceptDialog.new(); d.title="ثبت آگهی جدید"; var box=VBoxContainer.new()
    var title=LineEdit.new(); title.placeholder_text="عنوان ملک"; box.add_child(title)
    var city=LineEdit.new(); city.placeholder_text="شهر"; box.add_child(city)
    var nei=LineEdit.new(); nei.placeholder_text="محله"; box.add_child(nei)
    var typ=LineEdit.new(); typ.placeholder_text="فروش / اجاره"; box.add_child(typ)
    var price=LineEdit.new(); price.placeholder_text="قیمت"; box.add_child(price)
    var area=LineEdit.new(); area.placeholder_text="متراژ"; box.add_child(area)
    var phone=LineEdit.new(); phone.placeholder_text="شماره تماس"; box.add_child(phone)
    var desc=TextEdit.new(); desc.placeholder_text="توضیحات"; desc.custom_minimum_size.y=120; box.add_child(desc)
    d.add_child(box)
    d.confirmed.connect(func():
        var p={"title":title.text,"city":city.text,"neighborhood":nei.text,"type":typ.text,"price":price.text,"area":area.text,"phone":phone.text,"description":desc.text}
        var h=["Content-Type: application/json","Authorization: Bearer "+token]
        http.request(API_BASE+"/properties",h,HTTPClient.METHOD_POST,JSON.stringify(p))
    )
    add_child(d); d.popup_centered_ratio(0.85)

func _detail(p):
    var d=AcceptDialog.new(); d.title=str(p.get("title","جزئیات"))
    d.dialog_text="شهر: %s\nمحله: %s\nنوع: %s\nقیمت: %s\nمتراژ: %s\n\n%s\n\nتماس: %s" % [p.get("city",""),p.get("neighborhood",""),p.get("type",""),p.get("price",""),p.get("area",""),p.get("description",""),p.get("phone","")]
    add_child(d); d.popup_centered()
