import { createApp } from 'vue'
import './style.css'
import App from './App.vue'

// BigInt 無法原生 JSON 序列化，轉字串後前端再 parseInt
;(BigInt.prototype as any).toJSON = function () {
  return this.toString()
}

createApp(App).mount('#app')
