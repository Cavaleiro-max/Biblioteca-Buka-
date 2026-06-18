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
"https://github.com/Cavaleiro-max/Biblioteca-Buka-/releases/download/v1.0.0/app-release.1.apk";

info.innerText =
"Foi detetado um dispositivo Android.";

}
