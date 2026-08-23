package br.com.mimba.app;

import android.os.Bundle;
import androidx.activity.EdgeToEdge;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(MimbaBarsPlugin.class);
        super.onCreate(savedInstanceState);
        // @capacitor-community/safe-area cuida do resto (padding/insets
        // corretos em cada versão do WebView) — só precisa que o modo
        // edge-to-edge esteja ligado nativamente.
        EdgeToEdge.enable(this);
    }
}
