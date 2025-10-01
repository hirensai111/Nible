package com.example.nible

import android.app.Application
import com.stripe.android.PaymentConfiguration

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PaymentConfiguration.init(
            applicationContext,
            "pk_test_51RLXhpPMww4AvxzXhlLYmZwYoT8uh57eeXLX1jGXWF8GRMGx1cJSmhyINfmZTGTh90ExNQumQu8DNMXuIfsztxkL00OuZJTjwl"
        )
    }
}
