const btn = document.getElementById("downloadBtn");
const info = document.getElementById("deviceInfo");

const ua = navigator.userAgent;

const isIOS =
/iPad|iPhone|iPod/.test(ua);

const isAndroid =
/Android/.test(ua);

if (isIOS) {

    btn.innerText = "📱 Abrir versão iPhone";
    btn.href = "https://bukavirtual.netlify.app/";

    info.innerText =
    "Dispositivo Apple detectado.";

} else if (isAndroid) {

    btn.innerText =
    "⬇️ Baixar Buka+ Android";

    btn.href =
    "https://github.com/Cavaleiro-max/Biblioteca-Buka-/releases/download/v1.0.0/app-release.1.apk";

    info.innerText =
    "Dispositivo Android detectado.";

} else {

    btn.innerText =
    "⬇️ Baixar Buka+";

    btn.href =
    "https://github.com/Cavaleiro-max/Biblioteca-Buka-/releases/download/v1.0.0/app-release.1.apk";

    info.innerText =
    "Computador detectado.";

}
