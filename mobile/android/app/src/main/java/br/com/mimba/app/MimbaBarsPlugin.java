package br.com.mimba.app;

import android.graphics.Color;
import android.view.Window;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

// @capacitor-community/safe-area cuida do padding/insets, mas seu
// setSystemBarsStyle() pinta o fundo atrás da status/nav bar sempre em
// preto ou branco puro (hardcoded em SafeAreaPlugin.java, não lê o tema) —
// por isso o respiro aparecia preto em vez da cor da marca.
//
// Tentativa inicial foi pintar status bar e nav bar com cores independentes
// via Window.setStatusBarColor()/setNavigationBarColor() — mas com
// targetSdk 36 (Android força edge-to-edge a partir da API 35) essas APIs
// são no-op: só o estilo dos ícones (claro/escuro, via
// WindowInsetsControllerCompat) continua funcionando. Sobra
// decorView.setBackgroundColor() mesmo — uma cor só pra tela toda (top e
// bottom), igual o plugin community faz, só que aqui é a cor da marca em
// vez de preto/branco fixo. Prioriza o topo (é onde fica câmera/sinal/
// bateria, o bug original) — no login isso pode deixar o rodapé (atrás do
// gesture bar) meio verde em vez de creme, mas é bem menos visível que uma
// barra preta sólida.
@CapacitorPlugin(name = "MimbaBars")
public class MimbaBarsPlugin extends Plugin {
    @PluginMethod
    public void apply(PluginCall call) {
        String cor = call.getString("cor", "#F4EFE6");
        boolean escuro = Boolean.TRUE.equals(call.getBoolean("escuro", false));

        getActivity().runOnUiThread(() -> {
            Window window = getActivity().getWindow();
            WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
            controller.setAppearanceLightStatusBars(!escuro);
            controller.setAppearanceLightNavigationBars(!escuro);
            try {
                window.getDecorView().setBackgroundColor(Color.parseColor(cor));
            } catch (IllegalArgumentException ignored) {}
        });

        call.resolve();
    }
}
