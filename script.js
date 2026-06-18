const btn = document.getElementById("downloadBtn");
const info = document.getElementById("deviceInfo");

const isIOS =
/iPad|iPhone|iPod/.test(navigator.userAgent);

if(isIOS){

btn.innerText =
"📱 Abrir versão iPhone";

btn.href =
"pages/ios.html";

info.innerText =
"Foi detetado um dispositivo Apple.";

}else{

btn.innerText =
"⬇️ Baixar Buka+ Android";

btn.href =
"downloads/app-release.apk";

info.innerText =
"Foi detetado um dispositivo Android.";

}
