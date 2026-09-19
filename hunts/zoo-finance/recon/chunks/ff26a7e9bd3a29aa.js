(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,381036,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0}),Object.defineProperty(o,"warnOnce",{enumerable:!0,get:function(){return r}});let r=e=>{}},839561,e=>{"use strict";function t(e){return null==e}e.s(["isNil",()=>t])},858316,e=>{"use strict";var t=e.i(856244);e.s(["useSetState",0,function(e){void 0===e&&(e={});var o=(0,t.useState)(e),r=o[0],n=o[1];return[r,(0,t.useCallback)(function(e){n(function(t){return Object.assign({},t,e instanceof Function?e(t):e)})},[])]}],858316)},58619,e=>{"use strict";var t=e.i(856244),o=function(e,t){return"boolean"==typeof t?t:!e};e.s(["useToggle",0,function(e){return(0,t.useReducer)(o,e)}],58619)},147763,e=>{"use strict";var t=e.i(178895),o=e.i(318031),r=e.i(647163);let n={BERA:"BERA.svg",balance:"balance.png",berachain:"berachain.svg",berahub:"berahub.svg",Bull:"Bull.svg",coin:"coin.png",discord:"discord.png",discount:"discount.png",ETH:"ETH.svg",ethfi:"ethfi.png",ETHx:"ETHx.svg",galxe:"galxe.png",gift:"gift.png",gold:"gold.png",greenCycle:"greenCycle.png",GreenDot:"GreenDot.svg","HONEY-USDC":"HONEY-USDC.svg","USDC-HONEY":"HONEY-USDC.svg","HONEY-WBERA":"HONEY-WBERA.webp","HONEY-WBTC":"HONEY-WBTC.svg","HONEY-WETH":"HONEY-WETH.svg",HONEY:"HONEY.svg",iBGT:"iBGT.webp",iRED:"iRED.svg","logo-alt":"logo-alt.svg",Panda:"Panda.svg",piRED:"piRED.svg","status-green":"status-green.svg","status-red":"status-red.svg",twitter:"twitter.png",USDC:"USDC.svg",USDCx:"USDCx.svg",USDT:"USDT.svg",Venom:"Venom.svg",WBERA:"WBERA.svg",WBTC:"WBTC.svg",WBTCx:"WBTCx.svg",weeth:"weeth.png",weETH:"weETH.svg",weETHx:"weETHx.svg",WETH:"WETH.svg",xBERA:"xBERA.svg",xiBGT:"xiBGT.svg",yiRED:"yiRED.svg",ZUSD:"ZUSD.svg",BYUSD:"BYUSD.webp",Fire:"Fire.png",Lnfi:"lnfi.png",Reppo:"reppo.png",Enreach:"enreach.svg",Aethir:"Aethir.svg",Nodeops:"Nodeops.svg",ReppoNft:"ReppoNft.png","kodiak-logo":"kodiak-logo.svg",Opensea:"Opensea.svg",ZeroG:"ZeroG.png","0G":"0G.png",v0G:"v0G.png",y0G:"y0G.png",lp0G:"lp0G.png",Aethir2:"Aethir2.svg",aethir:"aethir.png",ATH:"ATH.png",vATH:"vATH.png",lpATH:"lpATH.png",Filecoin:"Filecoin.svg",Fil:"Filecoin.svg",vFil:"vFil.svg",lpFil:"lpFil.svg",REPPO:"REPPO.svg",Verio:"Verio.svg",IP:"IP.svg",SEI:"sei.svg"};function a({symbol:e,size:a=48,url:s,style:i,...l}){let c=n[e],p=`${o.BASE_PATH}/${c}`;return c||s?(0,t.jsx)("img",{...l,style:{width:a,height:a,...i||{}},className:(0,r.cn)(l.className),width:a,height:a,src:c?p:s,alt:e}):(0,t.jsxs)("svg",{...l,width:a,height:a,viewBox:"0 0 24 24",fill:"none",xmlns:"http://www.w3.org/2000/svg",children:[(0,t.jsx)("text",{className:"fill-primary/60",width:"20",x:"12",y:"14",textAnchor:"middle",fontSize:12,dominantBaseline:"middle",children:e.slice(0,2)}),(0,t.jsx)("circle",{className:"stroke-primary/60",cx:"12",cy:"12",r:"11.5",strokeWidth:1})]})}let s=["logo-alt","status-green","status-red","kodiak-logo"];function i({symbol1:e,symbol2:o,size:n=48,url1:s,url2:i,className:l}){return(0,t.jsxs)("div",{className:(0,r.cn)("flex items-center",l),children:[(0,t.jsx)(a,{symbol:e,size:n,url:s}),(0,t.jsx)(a,{symbol:o,size:n,url:i,style:{marginLeft:"-30%"}})]})}function l({symbol:e,size:o=48,url:r,...n}){if(e.includes("-")&&!s.includes(e)){let[r,a]=e.split("-");return(0,t.jsx)(i,{...n,symbol1:r,symbol2:a,size:o})}return(0,t.jsx)(a,{...n,symbol:e,size:o,url:r})}e.s(["CoinIcon",()=>l,"DoubleCoinIcon",()=>i])},944107,(e,t,o)=>{t.exports=e.r(90961)},406190,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0});var r={assign:function(){return l},searchParamsToUrlQuery:function(){return a},urlQueryToSearchParams:function(){return i}};for(var n in r)Object.defineProperty(o,n,{enumerable:!0,get:r[n]});function a(e){let t={};for(let[o,r]of e.entries()){let e=t[o];void 0===e?t[o]=r:Array.isArray(e)?e.push(r):t[o]=[e,r]}return t}function s(e){return"string"==typeof e?e:("number"!=typeof e||isNaN(e))&&"boolean"!=typeof e?"":String(e)}function i(e){let t=new URLSearchParams;for(let[o,r]of Object.entries(e))if(Array.isArray(r))for(let e of r)t.append(o,s(e));else t.set(o,s(r));return t}function l(e,...t){for(let o of t){for(let t of o.keys())e.delete(t);for(let[t,r]of o.entries())e.append(t,r)}return e}},593705,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0});var r={formatUrl:function(){return i},formatWithValidation:function(){return c},urlObjectKeys:function(){return l}};for(var n in r)Object.defineProperty(o,n,{enumerable:!0,get:r[n]});let a=e.r(744066)._(e.r(406190)),s=/https?|ftp|gopher|file/;function i(e){let{auth:t,hostname:o}=e,r=e.protocol||"",n=e.pathname||"",i=e.hash||"",l=e.query||"",c=!1;t=t?encodeURIComponent(t).replace(/%3A/i,":")+"@":"",e.host?c=t+e.host:o&&(c=t+(~o.indexOf(":")?`[${o}]`:o),e.port&&(c+=":"+e.port)),l&&"object"==typeof l&&(l=String(a.urlQueryToSearchParams(l)));let p=e.search||l&&`?${l}`||"";return r&&!r.endsWith(":")&&(r+=":"),e.slashes||(!r||s.test(r))&&!1!==c?(c="//"+(c||""),n&&"/"!==n[0]&&(n="/"+n)):c||(c=""),i&&"#"!==i[0]&&(i="#"+i),p&&"?"!==p[0]&&(p="?"+p),n=n.replace(/[?#]/g,encodeURIComponent),p=p.replace("#","%23"),`${r}${c}${n}${p}${i}`}let l=["auth","hash","host","hostname","href","path","pathname","port","protocol","query","search","slashes"];function c(e){return i(e)}},438563,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0}),Object.defineProperty(o,"useMergedRef",{enumerable:!0,get:function(){return n}});let r=e.r(856244);function n(e,t){let o=(0,r.useRef)(null),n=(0,r.useRef)(null);return(0,r.useCallback)(r=>{if(null===r){let e=o.current;e&&(o.current=null,e());let t=n.current;t&&(n.current=null,t())}else e&&(o.current=a(e,r)),t&&(n.current=a(t,r))},[e,t])}function a(e,t){if("function"!=typeof e)return e.current=t,()=>{e.current=null};{let o=e(t);return"function"==typeof o?o:()=>e(null)}}("function"==typeof o.default||"object"==typeof o.default&&null!==o.default)&&void 0===o.default.__esModule&&(Object.defineProperty(o.default,"__esModule",{value:!0}),Object.assign(o.default,o),t.exports=o.default)},275970,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0});var r={DecodeError:function(){return w},MiddlewareNotFoundError:function(){return v},MissingStaticPage:function(){return k},NormalizeError:function(){return b},PageNotFoundError:function(){return g},SP:function(){return f},ST:function(){return y},WEB_VITALS:function(){return a},execOnce:function(){return s},getDisplayName:function(){return u},getLocationOrigin:function(){return c},getURL:function(){return p},isAbsoluteUrl:function(){return l},isResSent:function(){return h},loadGetInitialProps:function(){return m},normalizeRepeatedSlashes:function(){return d},stringifyError:function(){return W}};for(var n in r)Object.defineProperty(o,n,{enumerable:!0,get:r[n]});let a=["CLS","FCP","FID","INP","LCP","TTFB"];function s(e){let t,o=!1;return(...r)=>(o||(o=!0,t=e(...r)),t)}let i=/^[a-zA-Z][a-zA-Z\d+\-.]*?:/,l=e=>i.test(e);function c(){let{protocol:e,hostname:t,port:o}=window.location;return`${e}//${t}${o?":"+o:""}`}function p(){let{href:e}=window.location,t=c();return e.substring(t.length)}function u(e){return"string"==typeof e?e:e.displayName||e.name||"Unknown"}function h(e){return e.finished||e.headersSent}function d(e){let t=e.split("?");return t[0].replace(/\\/g,"/").replace(/\/\/+/g,"/")+(t[1]?`?${t.slice(1).join("?")}`:"")}async function m(e,t){let o=t.res||t.ctx&&t.ctx.res;if(!e.getInitialProps)return t.ctx&&t.Component?{pageProps:await m(t.Component,t.ctx)}:{};let r=await e.getInitialProps(t);if(o&&h(o))return r;if(!r)throw Object.defineProperty(Error(`"${u(e)}.getInitialProps()" should resolve to an object. But found "${r}" instead.`),"__NEXT_ERROR_CODE",{value:"E394",enumerable:!1,configurable:!0});return r}let f="u">typeof performance,y=f&&["mark","measure","getEntriesByName"].every(e=>"function"==typeof performance[e]);class w extends Error{}class b extends Error{}class g extends Error{constructor(e){super(),this.code="ENOENT",this.name="PageNotFoundError",this.message=`Cannot find module for page: ${e}`}}class k extends Error{constructor(e,t){super(),this.message=`Failed to load static file for page: ${e} ${t}`}}class v extends Error{constructor(){super(),this.code="ENOENT",this.message="Cannot find the middleware module"}}function W(e){return JSON.stringify({message:e.message,stack:e.stack})}},674398,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0}),Object.defineProperty(o,"isLocalURL",{enumerable:!0,get:function(){return a}});let r=e.r(275970),n=e.r(870573);function a(e){if(!(0,r.isAbsoluteUrl)(e))return!0;try{let t=(0,r.getLocationOrigin)(),o=new URL(e,t);return o.origin===t&&(0,n.hasBasePath)(o.pathname)}catch(e){return!1}}},579458,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0}),Object.defineProperty(o,"errorOnce",{enumerable:!0,get:function(){return r}});let r=e=>{}},509175,(e,t,o)=>{"use strict";Object.defineProperty(o,"__esModule",{value:!0});var r={default:function(){return w},useLinkStatus:function(){return g}};for(var n in r)Object.defineProperty(o,n,{enumerable:!0,get:r[n]});let a=e.r(744066),s=e.r(178895),i=a._(e.r(856244)),l=e.r(593705),c=e.r(627420),p=e.r(438563),u=e.r(275970),h=e.r(768323);e.r(381036);let d=e.r(680518),m=e.r(674398),f=e.r(820604);function y(e){return"string"==typeof e?e:(0,l.formatUrl)(e)}function w(t){var o;let r,n,a,[l,w]=(0,i.useOptimistic)(d.IDLE_LINK_STATUS),g=(0,i.useRef)(null),{href:k,as:v,children:W,prefetch:C=null,passHref:x,replace:P,shallow:O,scroll:_,onClick:j,onMouseEnter:I,onTouchStart:T,legacyBehavior:R=!1,onNavigate:N,ref:E,unstable_dynamicOnHover:B,...A}=t;r=W,R&&("string"==typeof r||"number"==typeof r)&&(r=(0,s.jsx)("a",{children:r}));let S=i.default.useContext(c.AppRouterContext),q=!1!==C,L=!1!==C?null===(o=C)||"auto"===o?f.FetchStrategy.PPR:f.FetchStrategy.Full:f.FetchStrategy.PPR,{href:M,as:D}=i.default.useMemo(()=>{let e=y(k);return{href:e,as:v?y(v):e}},[k,v]);if(R){if(r?.$$typeof===Symbol.for("react.lazy"))throw Object.defineProperty(Error("`<Link legacyBehavior>` received a direct child that is either a Server Component, or JSX that was loaded with React.lazy(). This is not supported. Either remove legacyBehavior, or make the direct child a Client Component that renders the Link's `<a>` tag."),"__NEXT_ERROR_CODE",{value:"E863",enumerable:!1,configurable:!0});n=i.default.Children.only(r)}let U=R?n&&"object"==typeof n&&n.ref:E,F=i.default.useCallback(e=>(null!==S&&(g.current=(0,d.mountLinkInstance)(e,M,S,L,q,w)),()=>{g.current&&((0,d.unmountLinkForCurrentNavigation)(g.current),g.current=null),(0,d.unmountPrefetchableInstance)(e)}),[q,M,S,L,w]),H={ref:(0,p.useMergedRef)(F,U),onClick(t){R||"function"!=typeof j||j(t),R&&n.props&&"function"==typeof n.props.onClick&&n.props.onClick(t),!S||t.defaultPrevented||function(t,o,r,n,a,s,l){if("u">typeof window){let c,{nodeName:p}=t.currentTarget;if("A"===p.toUpperCase()&&((c=t.currentTarget.getAttribute("target"))&&"_self"!==c||t.metaKey||t.ctrlKey||t.shiftKey||t.altKey||t.nativeEvent&&2===t.nativeEvent.which)||t.currentTarget.hasAttribute("download"))return;if(!(0,m.isLocalURL)(o)){a&&(t.preventDefault(),location.replace(o));return}if(t.preventDefault(),l){let e=!1;if(l({preventDefault:()=>{e=!0}}),e)return}let{dispatchNavigateAction:u}=e.r(51553);i.default.startTransition(()=>{u(r||o,a?"replace":"push",s??!0,n.current)})}}(t,M,D,g,P,_,N)},onMouseEnter(e){R||"function"!=typeof I||I(e),R&&n.props&&"function"==typeof n.props.onMouseEnter&&n.props.onMouseEnter(e),S&&q&&(0,d.onNavigationIntent)(e.currentTarget,!0===B)},onTouchStart:function(e){R||"function"!=typeof T||T(e),R&&n.props&&"function"==typeof n.props.onTouchStart&&n.props.onTouchStart(e),S&&q&&(0,d.onNavigationIntent)(e.currentTarget,!0===B)}};return(0,u.isAbsoluteUrl)(D)?H.href=D:R&&!x&&("a"!==n.type||"href"in n.props)||(H.href=(0,h.addBasePath)(D)),a=R?i.default.cloneElement(n,H):(0,s.jsx)("a",{...A,...H,children:r}),(0,s.jsx)(b.Provider,{value:l,children:a})}e.r(579458);let b=(0,i.createContext)(d.IDLE_LINK_STATUS),g=()=>(0,i.useContext)(b);("function"==typeof o.default||"object"==typeof o.default&&null!==o.default)&&void 0===o.default.__esModule&&(Object.defineProperty(o.default,"__esModule",{value:!0}),Object.assign(o.default,o),t.exports=o.default)},479726,e=>{"use strict";var t=e.i(839561);function o(e){return(0,t.isNil)(e)?0:e instanceof Map||e instanceof Set?e.size:Object.keys(e).length}e.s(["size",()=>o])},625976,299203,e=>{"use strict";var t=e.i(781370),o=e.i(100231);function r(e,t,o){let r=e[t.name];if("function"==typeof r)return r;let n=e[o];return"function"==typeof n?n:o=>t(e,o)}async function n(e,t){let{allowFailure:n=!0,chainId:a,contracts:s,...i}=t;return r(e.getClient({chainId:a}),o.multicall,"multicall")({allowFailure:n,contracts:s,...i})}e.s(["getAction",()=>r],299203);var a=e.i(990389);async function s(e,o){let{allowFailure:s=!0,blockNumber:i,blockTag:l,...c}=o,p=o.contracts;try{let t={};for(let[o,r]of p.entries()){let n=r.chainId??e.state.chainId;t[n]||(t[n]=[]),t[n]?.push({contract:r,index:o})}let o=(await Promise.all(Object.entries(t).map(([t,o])=>n(e,{...c,allowFailure:s,blockNumber:i,blockTag:l,chainId:Number.parseInt(t,10),contracts:o.map(({contract:e})=>e)})))).flat(),r=Object.values(t).flatMap(e=>e.map(({index:e})=>e));return o.reduce((e,t,o)=>(e&&(e[r[o]]=t),e),[])}catch(n){if(n instanceof t.ContractFunctionExecutionError)throw n;let o=()=>p.map(t=>(function(e,t){let{chainId:o,...n}=t;return r(e.getClient({chainId:o}),a.readContract,"readContract")(n)})(e,{...t,blockNumber:i,blockTag:l}));if(s)return(await Promise.allSettled(o())).map(e=>"fulfilled"===e.status?{result:e.value,status:"success"}:{error:e.reason,result:void 0,status:"failure"});return await Promise.all(o())}}e.s(["readContracts",()=>s],625976)},153413,(e,t,o)=>{"use strict";var r=Object.prototype.hasOwnProperty,n="~";function a(){}function s(e,t,o){this.fn=e,this.context=t,this.once=o||!1}function i(e,t,o,r,a){if("function"!=typeof o)throw TypeError("The listener must be a function");var i=new s(o,r||e,a),l=n?n+t:t;return e._events[l]?e._events[l].fn?e._events[l]=[e._events[l],i]:e._events[l].push(i):(e._events[l]=i,e._eventsCount++),e}function l(e,t){0==--e._eventsCount?e._events=new a:delete e._events[t]}function c(){this._events=new a,this._eventsCount=0}Object.create&&(a.prototype=Object.create(null),new a().__proto__||(n=!1)),c.prototype.eventNames=function(){var e,t,o=[];if(0===this._eventsCount)return o;for(t in e=this._events)r.call(e,t)&&o.push(n?t.slice(1):t);return Object.getOwnPropertySymbols?o.concat(Object.getOwnPropertySymbols(e)):o},c.prototype.listeners=function(e){var t=n?n+e:e,o=this._events[t];if(!o)return[];if(o.fn)return[o.fn];for(var r=0,a=o.length,s=Array(a);r<a;r++)s[r]=o[r].fn;return s},c.prototype.listenerCount=function(e){var t=n?n+e:e,o=this._events[t];return o?o.fn?1:o.length:0},c.prototype.emit=function(e,t,o,r,a,s){var i=n?n+e:e;if(!this._events[i])return!1;var l,c,p=this._events[i],u=arguments.length;if(p.fn){switch(p.once&&this.removeListener(e,p.fn,void 0,!0),u){case 1:return p.fn.call(p.context),!0;case 2:return p.fn.call(p.context,t),!0;case 3:return p.fn.call(p.context,t,o),!0;case 4:return p.fn.call(p.context,t,o,r),!0;case 5:return p.fn.call(p.context,t,o,r,a),!0;case 6:return p.fn.call(p.context,t,o,r,a,s),!0}for(c=1,l=Array(u-1);c<u;c++)l[c-1]=arguments[c];p.fn.apply(p.context,l)}else{var h,d=p.length;for(c=0;c<d;c++)switch(p[c].once&&this.removeListener(e,p[c].fn,void 0,!0),u){case 1:p[c].fn.call(p[c].context);break;case 2:p[c].fn.call(p[c].context,t);break;case 3:p[c].fn.call(p[c].context,t,o);break;case 4:p[c].fn.call(p[c].context,t,o,r);break;default:if(!l)for(h=1,l=Array(u-1);h<u;h++)l[h-1]=arguments[h];p[c].fn.apply(p[c].context,l)}}return!0},c.prototype.on=function(e,t,o){return i(this,e,t,o,!1)},c.prototype.once=function(e,t,o){return i(this,e,t,o,!0)},c.prototype.removeListener=function(e,t,o,r){var a=n?n+e:e;if(!this._events[a])return this;if(!t)return l(this,a),this;var s=this._events[a];if(s.fn)s.fn!==t||r&&!s.once||o&&s.context!==o||l(this,a);else{for(var i=0,c=[],p=s.length;i<p;i++)(s[i].fn!==t||r&&!s[i].once||o&&s[i].context!==o)&&c.push(s[i]);c.length?this._events[a]=1===c.length?c[0]:c:l(this,a)}return this},c.prototype.removeAllListeners=function(e){var t;return e?(t=n?n+e:e,this._events[t]&&l(this,t)):(this._events=new a,this._eventsCount=0),this},c.prototype.off=c.prototype.removeListener,c.prototype.addListener=c.prototype.on,c.prefixed=n,c.EventEmitter=c,t.exports=c},785373,50158,e=>{"use strict";var t=e.i(153413);t.default,e.s([],785373),e.s(["EventEmitter",()=>t.default],50158)},258083,e=>{"use strict";var t=`{
  "connect_wallet": {
    "label": "Connect Wallet",
    "wrong_network": {
      "label": "Wrong network"
    }
  },

  "intro": {
    "title": "What is a Wallet?",
    "description": "A wallet is used to send, receive, store, and display digital assets. It's also a new way to log in, without needing to create new accounts and passwords on every website.",
    "digital_asset": {
      "title": "A Home for your Digital Assets",
      "description": "Wallets are used to send, receive, store, and display digital assets like Ethereum and NFTs."
    },
    "login": {
      "title": "A New Way to Log In",
      "description": "Instead of creating new accounts and passwords on every website, just connect your wallet."
    },
    "get": {
      "label": "Get a Wallet"
    },
    "learn_more": {
      "label": "Learn More"
    }
  },

  "sign_in": {
    "label": "Verify your account",
    "description": "To finish connecting, you must sign a message in your wallet to verify that you are the owner of this account.",
    "message": {
      "send": "Sign message",
      "preparing": "Preparing message...",
      "cancel": "Cancel",
      "preparing_error": "Error preparing message, please retry!"
    },
    "signature": {
      "waiting": "Waiting for signature...",
      "verifying": "Verifying signature...",
      "signing_error": "Error signing message, please retry!",
      "verifying_error": "Error verifying signature, please retry!",
      "oops_error": "Oops, something went wrong!"
    }
  },

  "connect": {
    "label": "Connect",
    "title": "Connect a Wallet",
    "new_to_ethereum": {
      "description": "New to Ethereum wallets?",
      "learn_more": {
        "label": "Learn More"
      }
    },
    "learn_more": {
      "label": "Learn more"
    },
    "recent": "Recent",
    "status": {
      "opening": "Opening %{wallet}...",
      "connecting": "Connecting",
      "connect_mobile": "Continue in %{wallet}",
      "not_installed": "%{wallet} is not installed",
      "not_available": "%{wallet} is not available",
      "confirm": "Confirm connection in the extension",
      "confirm_mobile": "Accept connection request in the wallet"
    },
    "secondary_action": {
      "get": {
        "description": "Don't have %{wallet}?",
        "label": "GET"
      },
      "install": {
        "label": "INSTALL"
      },
      "retry": {
        "label": "RETRY"
      }
    },
    "walletconnect": {
      "description": {
        "full": "Need the official WalletConnect modal?",
        "compact": "Need the WalletConnect modal?"
      },
      "open": {
        "label": "OPEN"
      }
    }
  },

  "connect_scan": {
    "title": "Scan with %{wallet}",
    "fallback_title": "Scan with your phone"
  },

  "connector_group": {
    "installed": "Installed",
    "recommended": "Recommended",
    "other": "Other",
    "popular": "Popular",
    "more": "More",
    "others": "Others"
  },

  "get": {
    "title": "Get a Wallet",
    "action": {
      "label": "GET"
    },
    "mobile": {
      "description": "Mobile Wallet"
    },
    "extension": {
      "description": "Browser Extension"
    },
    "mobile_and_extension": {
      "description": "Mobile Wallet and Extension"
    },
    "mobile_and_desktop": {
      "description": "Mobile and Desktop Wallet"
    },
    "looking_for": {
      "title": "Not what you're looking for?",
      "mobile": {
        "description": "Select a wallet on the main screen to get started with a different wallet provider."
      },
      "desktop": {
        "compact_description": "Select a wallet on the main screen to get started with a different wallet provider.",
        "wide_description": "Select a wallet on the left to get started with a different wallet provider."
      }
    }
  },

  "get_options": {
    "title": "Get started with %{wallet}",
    "short_title": "Get %{wallet}",
    "mobile": {
      "title": "%{wallet} for Mobile",
      "description": "Use the mobile wallet to explore the world of Ethereum.",
      "download": {
        "label": "Get the app"
      }
    },
    "extension": {
      "title": "%{wallet} for %{browser}",
      "description": "Access your wallet right from your favorite web browser.",
      "download": {
        "label": "Add to %{browser}"
      }
    },
    "desktop": {
      "title": "%{wallet} for %{platform}",
      "description": "Access your wallet natively from your powerful desktop.",
      "download": {
        "label": "Add to %{platform}"
      }
    }
  },

  "get_mobile": {
    "title": "Install %{wallet}",
    "description": "Scan with your phone to download on iOS or Android",
    "continue": {
      "label": "Continue"
    }
  },

  "get_instructions": {
    "mobile": {
      "connect": {
        "label": "Connect"
      },
      "learn_more": {
        "label": "Learn More"
      }
    },
    "extension": {
      "refresh": {
        "label": "Refresh"
      },
      "learn_more": {
        "label": "Learn More"
      }
    },
    "desktop": {
      "connect": {
        "label": "Connect"
      },
      "learn_more": {
        "label": "Learn More"
      }
    }
  },

  "chains": {
    "title": "Switch Networks",
    "wrong_network": "Wrong network detected, switch or disconnect to continue.",
    "confirm": "Confirm in Wallet",
    "switching_not_supported": "Your wallet does not support switching networks from %{appName}. Try switching networks from within your wallet instead.",
    "switching_not_supported_fallback": "Your wallet does not support switching networks from this app. Try switching networks from within your wallet instead.",
    "disconnect": "Disconnect",
    "connected": "Connected"
  },

  "profile": {
    "disconnect": {
      "label": "Disconnect"
    },
    "copy_address": {
      "label": "Copy Address",
      "copied": "Copied!"
    },
    "explorer": {
      "label": "View more on explorer"
    },
    "transactions": {
      "description": "%{appName} transactions will appear here...",
      "description_fallback": "Your transactions will appear here...",
      "recent": {
        "title": "Recent Transactions"
      },
      "clear": {
        "label": "Clear All"
      }
    }
  },

  "wallet_connectors": {
    "argent": {
      "qr_code": {
        "step1": {
          "description": "Put Argent on your home screen for faster access to your wallet.",
          "title": "Open the Argent app"
        },
        "step2": {
          "description": "Create a wallet and username, or import an existing wallet.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the Scan QR button"
        }
      }
    },

    "berasig": {
      "extension": {
        "step1": {
          "title": "Install the BeraSig extension",
          "description": "We recommend pinning BeraSig to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "best": {
      "qr_code": {
        "step1": {
          "title": "Open the Best Wallet app",
          "description": "Add Best Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "bifrost": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Bifrost Wallet on your home screen for quicker access.",
          "title": "Open the Bifrost Wallet app"
        },
        "step2": {
          "description": "Create or import a wallet using your recovery phrase.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      }
    },

    "bitget": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Bitget Wallet on your home screen for quicker access.",
          "title": "Open the Bitget Wallet app"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      },

      "extension": {
        "step1": {
          "description": "We recommend pinning Bitget Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Bitget Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "bitski": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Bitski to your taskbar for quicker access to your wallet.",
          "title": "Install the Bitski extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "bitverse": {
      "qr_code": {
        "step1": {
          "title": "Open the Bitverse Wallet app",
          "description": "Add Bitverse Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "bloom": {
      "desktop": {
        "step1": {
          "title": "Open the Bloom Wallet app",
          "description": "We recommend putting Bloom Wallet on your home screen for quicker access."
        },
        "step2": {
          "description": "Create or import a wallet using your recovery phrase.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you have a wallet, click on Connect to connect via Bloom. A connection prompt in the app will appear for you to confirm the connection.",
          "title": "Click on Connect"
        }
      }
    },

    "bybit": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Bybit on your home screen for faster access to your wallet.",
          "title": "Open the Bybit app"
        },
        "step2": {
          "description": "You can easily backup your wallet using our backup feature on your phone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      },

      "extension": {
        "step1": {
          "description": "Click at the top right of your browser and pin Bybit Wallet for easy access.",
          "title": "Install the Bybit Wallet extension"
        },
        "step2": {
          "description": "Create a new wallet or import an existing one.",
          "title": "Create or Import a wallet"
        },
        "step3": {
          "description": "Once you set up Bybit Wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "binance": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Binance on your home screen for faster access to your wallet.",
          "title": "Open the Binance app"
        },
        "step2": {
          "description": "You can easily backup your wallet using our backup feature on your phone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the WalletConnect button"
        }
      },
      "extension": {
        "step1": {
          "title": "Install the Binance Wallet extension",
          "description": "We recommend pinning Binance Wallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "coin98": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Coin98 Wallet on your home screen for faster access to your wallet.",
          "title": "Open the Coin98 Wallet app"
        },
        "step2": {
          "description": "You can easily backup your wallet using our backup feature on your phone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the WalletConnect button"
        }
      },

      "extension": {
        "step1": {
          "description": "Click at the top right of your browser and pin Coin98 Wallet for easy access.",
          "title": "Install the Coin98 Wallet extension"
        },
        "step2": {
          "description": "Create a new wallet or import an existing one.",
          "title": "Create or Import a wallet"
        },
        "step3": {
          "description": "Once you set up Coin98 Wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "coinbase": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Coinbase Wallet on your home screen for quicker access.",
          "title": "Open the Coinbase Wallet app"
        },
        "step2": {
          "description": "You can easily backup your wallet using the cloud backup feature.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      },

      "extension": {
        "step1": {
          "description": "We recommend pinning Coinbase Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Coinbase Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "compass": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Compass Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Compass Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "core": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Core on your home screen for faster access to your wallet.",
          "title": "Open the Core app"
        },
        "step2": {
          "description": "You can easily backup your wallet using our backup feature on your phone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the WalletConnect button"
        }
      },

      "extension": {
        "step1": {
          "description": "We recommend pinning Core to your taskbar for quicker access to your wallet.",
          "title": "Install the Core extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "fox": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting FoxWallet on your home screen for quicker access.",
          "title": "Open the FoxWallet app"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      }
    },

    "frontier": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Frontier Wallet on your home screen for quicker access.",
          "title": "Open the Frontier Wallet app"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      },

      "extension": {
        "step1": {
          "description": "We recommend pinning Frontier Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Frontier Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "im_token": {
      "qr_code": {
        "step1": {
          "title": "Open the imToken app",
          "description": "Put imToken app on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap Scanner Icon in top right corner",
          "description": "Choose New Connection, then scan the QR code and confirm the prompt to connect."
        }
      }
    },

    "iopay": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting ioPay on your home screen for faster access to your wallet.",
          "title": "Open the ioPay app"
        },
        "step2": {
          "description": "You can easily backup your wallet using our backup feature on your phone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the WalletConnect button"
        }
      }
    },

    "kaikas": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Kaikas to your taskbar for quicker access to your wallet.",
          "title": "Install the Kaikas extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the Kaikas app",
          "description": "Put Kaikas app on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap Scanner Icon in top right corner",
          "description": "Choose New Connection, then scan the QR code and confirm the prompt to connect."
        }
      }
    },

    "kaia": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Kaia to your taskbar for quicker access to your wallet.",
          "title": "Install the Kaia extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the Kaia app",
          "description": "Put Kaia app on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap Scanner Icon in top right corner",
          "description": "Choose New Connection, then scan the QR code and confirm the prompt to connect."
        }
      }
    },

    "kraken": {
      "qr_code": {
        "step1": {
          "title": "Open the Kraken Wallet app",
          "description": "Add Kraken Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "kresus": {
      "qr_code": {
        "step1": {
          "title": "Open the Kresus Wallet app",
          "description": "Add Kresus Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "magicEden": {
      "extension": {
        "step1": {
          "title": "Install the Magic Eden extension",
          "description": "We recommend pinning Magic Eden to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret recovery phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "metamask": {
      "qr_code": {
        "step1": {
          "title": "Open the MetaMask app",
          "description": "We recommend putting MetaMask on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      },

      "extension": {
        "step1": {
          "title": "Install the MetaMask extension",
          "description": "We recommend pinning MetaMask to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "nestwallet": {
      "extension": {
        "step1": {
          "title": "Install the NestWallet extension",
          "description": "We recommend pinning NestWallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "okx": {
      "qr_code": {
        "step1": {
          "title": "Open the OKX Wallet app",
          "description": "We recommend putting OKX Wallet on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      },

      "extension": {
        "step1": {
          "title": "Install the OKX Wallet extension",
          "description": "We recommend pinning OKX Wallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "omni": {
      "qr_code": {
        "step1": {
          "title": "Open the Omni app",
          "description": "Add Omni to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your home screen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "1inch": {
      "qr_code": {
        "step1": {
          "description": "Put 1inch Wallet on your home screen for faster access to your wallet.",
          "title": "Open the 1inch Wallet app"
        },
        "step2": {
          "description": "Create a wallet and username, or import an existing wallet.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the Scan QR button"
        }
      }
    },

    "token_pocket": {
      "qr_code": {
        "step1": {
          "title": "Open the TokenPocket app",
          "description": "We recommend putting TokenPocket on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      },

      "extension": {
        "step1": {
          "title": "Install the TokenPocket extension",
          "description": "We recommend pinning TokenPocket to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "trust": {
      "qr_code": {
        "step1": {
          "title": "Open the Trust Wallet app",
          "description": "Put Trust Wallet on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap WalletConnect in Settings",
          "description": "Choose New Connection, then scan the QR code and confirm the prompt to connect."
        }
      },

      "extension": {
        "step1": {
          "title": "Install the Trust Wallet extension",
          "description": "Click at the top right of your browser and pin Trust Wallet for easy access."
        },
        "step2": {
          "title": "Create or Import a wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up Trust Wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "uniswap": {
      "qr_code": {
        "step1": {
          "title": "Open the Uniswap app",
          "description": "Add Uniswap Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "zerion": {
      "qr_code": {
        "step1": {
          "title": "Open the Zerion app",
          "description": "We recommend putting Zerion on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      },

      "extension": {
        "step1": {
          "title": "Install the Zerion extension",
          "description": "We recommend pinning Zerion to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "rainbow": {
      "qr_code": {
        "step1": {
          "title": "Open the Rainbow app",
          "description": "We recommend putting Rainbow on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "You can easily backup your wallet using our backup feature on your phone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "enkrypt": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Enkrypt Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Enkrypt Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "frame": {
      "extension": {
        "step1": {
          "description": "We recommend pinning Frame to your taskbar for quicker access to your wallet.",
          "title": "Install Frame & the companion extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "one_key": {
      "extension": {
        "step1": {
          "title": "Install the OneKey Wallet extension",
          "description": "We recommend pinning OneKey Wallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "paraswap": {
      "qr_code": {
        "step1": {
          "title": "Open the ParaSwap app",
          "description": "Add ParaSwap Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      }
    },

    "phantom": {
      "extension": {
        "step1": {
          "title": "Install the Phantom extension",
          "description": "We recommend pinning Phantom to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret recovery phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "rabby": {
      "extension": {
        "step1": {
          "title": "Install the Rabby extension",
          "description": "We recommend pinning Rabby to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "ronin": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting Ronin Wallet on your home screen for quicker access.",
          "title": "Open the Ronin Wallet app"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      },

      "extension": {
        "step1": {
          "description": "We recommend pinning Ronin Wallet to your taskbar for quicker access to your wallet.",
          "title": "Install the Ronin Wallet extension"
        },
        "step2": {
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension.",
          "title": "Refresh your browser"
        }
      }
    },

    "ramper": {
      "extension": {
        "step1": {
          "title": "Install the Ramper extension",
          "description": "We recommend pinning Ramper to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "safeheron": {
      "extension": {
        "step1": {
          "title": "Install the Core extension",
          "description": "We recommend pinning Safeheron to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "taho": {
      "extension": {
        "step1": {
          "title": "Install the Taho extension",
          "description": "We recommend pinning Taho to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "wigwam": {
      "extension": {
        "step1": {
          "title": "Install the Wigwam extension",
          "description": "We recommend pinning Wigwam to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "talisman": {
      "extension": {
        "step1": {
          "title": "Install the Talisman extension",
          "description": "We recommend pinning Talisman to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import an Ethereum Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your recovery phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "xdefi": {
      "extension": {
        "step1": {
          "title": "Install the XDEFI Wallet extension",
          "description": "We recommend pinning XDEFI Wallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "zeal": {
      "qr_code": {
        "step1": {
          "title": "Open the Zeal app",
          "description": "Add Zeal Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the QR icon and scan",
          "description": "Tap the QR icon on your homescreen, scan the code and confirm the prompt to connect."
        }
      },
      "extension": {
        "step1": {
          "title": "Install the Zeal extension",
          "description": "We recommend pinning Zeal to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "safepal": {
      "extension": {
        "step1": {
          "title": "Install the SafePal Wallet extension",
          "description": "Click at the top right of your browser and pin SafePal Wallet for easy access."
        },
        "step2": {
          "title": "Create or Import a wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up SafePal Wallet, click below to refresh the browser and load up the extension."
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the SafePal Wallet app",
          "description": "Put SafePal Wallet on your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap WalletConnect in Settings",
          "description": "Choose New Connection, then scan the QR code and confirm the prompt to connect."
        }
      }
    },

    "desig": {
      "extension": {
        "step1": {
          "title": "Install the Desig extension",
          "description": "We recommend pinning Desig to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "subwallet": {
      "extension": {
        "step1": {
          "title": "Install the SubWallet extension",
          "description": "We recommend pinning SubWallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your recovery phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the SubWallet app",
          "description": "We recommend putting SubWallet on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "clv": {
      "extension": {
        "step1": {
          "title": "Install the CLV Wallet extension",
          "description": "We recommend pinning CLV Wallet to your taskbar for quicker access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the CLV Wallet app",
          "description": "We recommend putting CLV Wallet on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret phrase with anyone."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "okto": {
      "qr_code": {
        "step1": {
          "title": "Open the Okto app",
          "description": "Add Okto to your home screen for quick access"
        },
        "step2": {
          "title": "Create an MPC Wallet",
          "description": "Create an account and generate a wallet"
        },
        "step3": {
          "title": "Tap WalletConnect in Settings",
          "description": "Tap the Scan QR icon at the top right and confirm the prompt to connect."
        }
      }
    },

    "ledger": {
      "desktop": {
        "step1": {
          "title": "Open the Ledger Live app",
          "description": "We recommend putting Ledger Live on your home screen for quicker access."
        },
        "step2": {
          "title": "Set up your Ledger",
          "description": "Set up a new Ledger or connect to an existing one."
        },
        "step3": {
          "title": "Connect",
          "description": "A connection prompt will appear for you to connect your wallet."
        }
      },
      "qr_code": {
        "step1": {
          "title": "Open the Ledger Live app",
          "description": "We recommend putting Ledger Live on your home screen for quicker access."
        },
        "step2": {
          "title": "Set up your Ledger",
          "description": "You can either sync with the desktop app or connect your Ledger."
        },
        "step3": {
          "title": "Scan the code",
          "description": "Tap WalletConnect then Switch to Scanner. After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "valora": {
      "qr_code": {
        "step1": {
          "title": "Open the Valora app",
          "description": "We recommend putting Valora on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or import a wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "gate": {
      "qr_code": {
        "step1": {
          "title": "Open the Gate app",
          "description": "We recommend putting Gate on your home screen for quicker access."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      },
      "extension": {
        "step1": {
          "title": "Install the Gate extension",
          "description": "We recommend pinning Gate to your taskbar for easier access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Be sure to back up your wallet using a secure method. Never share your secret recovery phrase with anyone."
        },
        "step3": {
          "title": "Refresh your browser",
          "description": "Once you set up your wallet, click below to refresh the browser and load up the extension."
        }
      }
    },

    "gemini": {
      "qr_code": {
        "step1": {
          "title": "Open keys.gemini.com",
          "description": "Visit keys.gemini.com on your mobile browser - no app download required."
        },
        "step2": {
          "title": "Create Your Wallet Instantly",
          "description": "Set up your smart wallet in seconds using your device's built-in authentication."
        },
        "step3": {
          "title": "Scan to Connect",
          "description": "Scan the QR code to instantly connect your wallet - it just works."
        }
      },
      "extension": {
        "step1": {
          "title": "Go to keys.gemini.com",
          "description": "No extensions or downloads needed - your wallet lives securely in the browser."
        },
        "step2": {
          "title": "One-Click Setup",
          "description": "Create your smart wallet instantly with passkey authentication - easier than any wallet out there."
        },
        "step3": {
          "title": "Connect and Go",
          "description": "Approve the connection and you're ready - the unopinionated wallet that just works."
        }
      }
    },

    "xportal": {
      "qr_code": {
        "step1": {
          "description": "Put xPortal on your home screen for faster access to your wallet.",
          "title": "Open the xPortal app"
        },
        "step2": {
          "description": "Create a wallet or import an existing one.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the Scan QR button"
        }
      }
    },

    "mew": {
      "qr_code": {
        "step1": {
          "description": "We recommend putting MEW Wallet on your home screen for quicker access.",
          "title": "Open the MEW Wallet app"
        },
        "step2": {
          "description": "You can easily backup your wallet using the cloud backup feature.",
          "title": "Create or Import a Wallet"
        },
        "step3": {
          "description": "After you scan, a connection prompt will appear for you to connect your wallet.",
          "title": "Tap the scan button"
        }
      }
    },

    "zilpay": {
      "qr_code": {
        "step1": {
          "title": "Open the ZilPay app",
          "description": "Add ZilPay to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    },

    "nova": {
      "qr_code": {
        "step1": {
          "title": "Open the Nova Wallet app",
          "description": "Add Nova Wallet to your home screen for faster access to your wallet."
        },
        "step2": {
          "title": "Create or Import a Wallet",
          "description": "Create a new wallet or import an existing one."
        },
        "step3": {
          "title": "Tap the scan button",
          "description": "After you scan, a connection prompt will appear for you to connect your wallet."
        }
      }
    }
  }
}
`;e.s(["en_US_default",()=>t])},52607,e=>{e.v(t=>Promise.all(["static/chunks/59f46d4dc3261383.js"].map(t=>e.l(t))).then(()=>t(73549)))},156764,e=>{e.v(t=>Promise.all(["static/chunks/d2827c42f1f4ac82.js"].map(t=>e.l(t))).then(()=>t(163834)))},313886,e=>{e.v(e=>Promise.resolve().then(()=>e(300059)))},962536,e=>{e.v(t=>Promise.all(["static/chunks/b40f8c67c12db9c2.js","static/chunks/9afb366b39fbf594.js","static/chunks/5654c993ebe76fd2.js"].map(t=>e.l(t))).then(()=>t(991151)))},199758,e=>{e.v(t=>Promise.all(["static/chunks/f92d031ee667556d.js","static/chunks/67049b5e4d00d00b.js"].map(t=>e.l(t))).then(()=>t(14897)))},138813,e=>{e.v(t=>Promise.all(["static/chunks/4b313d2640fc0f97.js"].map(t=>e.l(t))).then(()=>t(808278)))},422017,e=>{e.v(t=>Promise.all(["static/chunks/8ecd23058f942871.js"].map(t=>e.l(t))).then(()=>t(90419)))},722971,e=>{e.v(t=>Promise.all(["static/chunks/f9f95461d6cff7f2.js","static/chunks/41f7fae15085eb28.js"].map(t=>e.l(t))).then(()=>t(127955)))},417430,e=>{e.v(t=>Promise.all(["static/chunks/30686307d86ad7c3.js"].map(t=>e.l(t))).then(()=>t(581937)))},133483,e=>{e.v(t=>Promise.all(["static/chunks/84fef01c33c2035b.js"].map(t=>e.l(t))).then(()=>t(825393)))},282605,e=>{e.v(t=>Promise.all(["static/chunks/3499973f66033e2d.js"].map(t=>e.l(t))).then(()=>t(760210)))},113418,e=>{e.v(t=>Promise.all(["static/chunks/8311e3ef6da95280.js"].map(t=>e.l(t))).then(()=>t(453902)))},381024,e=>{e.v(t=>Promise.all(["static/chunks/154a48b78b3d3000.js"].map(t=>e.l(t))).then(()=>t(186732)))},435896,e=>{e.v(t=>Promise.all(["static/chunks/1b291184770fb882.js"].map(t=>e.l(t))).then(()=>t(107126)))},806197,e=>{e.v(t=>Promise.all(["static/chunks/134122edce16ef54.js"].map(t=>e.l(t))).then(()=>t(725176)))},281023,e=>{e.v(t=>Promise.all(["static/chunks/45c47c0d226d49b2.js"].map(t=>e.l(t))).then(()=>t(925153)))},357433,e=>{e.v(t=>Promise.all(["static/chunks/b766a6519fe71553.js"].map(t=>e.l(t))).then(()=>t(765908)))},481458,e=>{e.v(t=>Promise.all(["static/chunks/3080bfcaf8395603.js"].map(t=>e.l(t))).then(()=>t(519636)))},36743,e=>{e.v(t=>Promise.all(["static/chunks/6f3f4d042b14efd0.js"].map(t=>e.l(t))).then(()=>t(373376)))},389826,e=>{e.v(t=>Promise.all(["static/chunks/538b5498ea7af6cb.js"].map(t=>e.l(t))).then(()=>t(608068)))},837466,e=>{e.v(t=>Promise.all(["static/chunks/dbb58bdfcfaeb56f.js"].map(t=>e.l(t))).then(()=>t(218166)))},429948,e=>{e.v(t=>Promise.all(["static/chunks/3f8199ecf57c62f6.js"].map(t=>e.l(t))).then(()=>t(490795)))},716103,e=>{e.v(t=>Promise.all(["static/chunks/6149dc2640d9b5ea.js"].map(t=>e.l(t))).then(()=>t(849216)))},227497,e=>{e.v(t=>Promise.all(["static/chunks/9912bb95aa605b12.js"].map(t=>e.l(t))).then(()=>t(897217)))},206562,e=>{e.v(t=>Promise.all(["static/chunks/f5df3f8589dba130.js"].map(t=>e.l(t))).then(()=>t(868420)))},825469,e=>{e.v(t=>Promise.all(["static/chunks/c5f7e78e4e38c161.js"].map(t=>e.l(t))).then(()=>t(420550)))},728442,e=>{e.v(t=>Promise.all(["static/chunks/0ef84335a93594a4.js"].map(t=>e.l(t))).then(()=>t(918277)))},894041,e=>{e.v(t=>Promise.all(["static/chunks/0381715eca3e3b19.js"].map(t=>e.l(t))).then(()=>t(916476)))},517021,e=>{e.v(t=>Promise.all(["static/chunks/6f2ca98bbeb5c08e.js"].map(t=>e.l(t))).then(()=>t(315086)))},910404,e=>{e.v(t=>Promise.all(["static/chunks/7e3fc8004f2e9317.js"].map(t=>e.l(t))).then(()=>t(764137)))},618478,e=>{e.v(t=>Promise.all(["static/chunks/cdf87c69a6aed0b2.js"].map(t=>e.l(t))).then(()=>t(71771)))},165995,e=>{e.v(t=>Promise.all(["static/chunks/31a35a44afda4bec.js"].map(t=>e.l(t))).then(()=>t(265899)))},977551,e=>{e.v(t=>Promise.all(["static/chunks/b78650f0ab957656.js"].map(t=>e.l(t))).then(()=>t(859835)))},668982,e=>{e.v(t=>Promise.all(["static/chunks/86b529bb864912a3.js"].map(t=>e.l(t))).then(()=>t(383470)))},110191,e=>{e.v(t=>Promise.all(["static/chunks/7b3c63e3aac6325c.js"].map(t=>e.l(t))).then(()=>t(157515)))},867189,e=>{e.v(t=>Promise.all(["static/chunks/b688b0c35c69420b.js"].map(t=>e.l(t))).then(()=>t(536056)))},503476,e=>{e.v(t=>Promise.all(["static/chunks/b668326433d3d13c.js"].map(t=>e.l(t))).then(()=>t(635995)))},98926,e=>{e.v(t=>Promise.all(["static/chunks/5fc000ffa6258a00.js"].map(t=>e.l(t))).then(()=>t(278514)))},951266,e=>{e.v(t=>Promise.all(["static/chunks/62710a59bedb788c.js"].map(t=>e.l(t))).then(()=>t(324807)))},566007,e=>{e.v(t=>Promise.all(["static/chunks/abb4806424c07afa.js"].map(t=>e.l(t))).then(()=>t(160300)))},541158,e=>{e.v(t=>Promise.all(["static/chunks/6f47ba4b6b785b5d.js"].map(t=>e.l(t))).then(()=>t(517981)))},584487,e=>{e.v(t=>Promise.all(["static/chunks/274d38bb19420977.js"].map(t=>e.l(t))).then(()=>t(140801)))},340559,e=>{e.v(t=>Promise.all(["static/chunks/d6d8ad533a507bb9.js"].map(t=>e.l(t))).then(()=>t(537070)))},201513,e=>{e.v(t=>Promise.all(["static/chunks/51e03898847474b6.js"].map(t=>e.l(t))).then(()=>t(597444)))},534958,e=>{e.v(t=>Promise.all(["static/chunks/0b035eecff50f502.js"].map(t=>e.l(t))).then(()=>t(941445)))},945282,e=>{e.v(t=>Promise.all(["static/chunks/154bf337dd90a4f5.js"].map(t=>e.l(t))).then(()=>t(820538)))},704225,e=>{e.v(t=>Promise.all(["static/chunks/6bc0771988fe75ae.js"].map(t=>e.l(t))).then(()=>t(274711)))},177522,e=>{e.v(t=>Promise.all(["static/chunks/54f8d3582eea63a2.js"].map(t=>e.l(t))).then(()=>t(129737)))},466492,e=>{e.v(t=>Promise.all(["static/chunks/36cba99f358e9a8a.js"].map(t=>e.l(t))).then(()=>t(980139)))},905670,e=>{e.v(t=>Promise.all(["static/chunks/c4567edeebe20f11.js"].map(t=>e.l(t))).then(()=>t(2441)))},421746,e=>{e.v(t=>Promise.all(["static/chunks/56f3a399d49bd076.js"].map(t=>e.l(t))).then(()=>t(677644)))},694192,e=>{e.v(t=>Promise.all(["static/chunks/285e902090ca6664.js"].map(t=>e.l(t))).then(()=>t(811901)))},637476,e=>{e.v(t=>Promise.all(["static/chunks/05a4120ebbb9e87c.js"].map(t=>e.l(t))).then(()=>t(564600)))},522219,e=>{e.v(t=>Promise.all(["static/chunks/fb2de0cedf538407.js"].map(t=>e.l(t))).then(()=>t(838809)))},295837,e=>{e.v(t=>Promise.all(["static/chunks/d9ddd9581638c1f3.js"].map(t=>e.l(t))).then(()=>t(564003)))},586439,e=>{e.v(t=>Promise.all(["static/chunks/7ddc8b912b3937df.js"].map(t=>e.l(t))).then(()=>t(108336)))},78659,e=>{e.v(t=>Promise.all(["static/chunks/073595ee1a7d5f9b.js"].map(t=>e.l(t))).then(()=>t(992590)))},507424,e=>{e.v(t=>Promise.all(["static/chunks/78ffbbf59c44f060.js"].map(t=>e.l(t))).then(()=>t(525394)))},775216,e=>{e.v(t=>Promise.all(["static/chunks/10ba815f6c8c9f4a.js"].map(t=>e.l(t))).then(()=>t(248798)))},953605,e=>{e.v(t=>Promise.all(["static/chunks/677366996445695d.js"].map(t=>e.l(t))).then(()=>t(558251)))},484906,e=>{e.v(t=>Promise.all(["static/chunks/1100227ca0171462.js"].map(t=>e.l(t))).then(()=>t(270631)))},656520,e=>{e.v(t=>Promise.all(["static/chunks/8b2b333237ee2e3b.js"].map(t=>e.l(t))).then(()=>t(3251)))},464675,e=>{e.v(t=>Promise.all(["static/chunks/6daae1bd75d648e7.js"].map(t=>e.l(t))).then(()=>t(121337)))},42244,e=>{e.v(t=>Promise.all(["static/chunks/e0376afd3beaab68.js"].map(t=>e.l(t))).then(()=>t(860992)))},244756,e=>{e.v(t=>Promise.all(["static/chunks/6a55e46ec596b76b.js"].map(t=>e.l(t))).then(()=>t(796009)))},646307,e=>{e.v(t=>Promise.all(["static/chunks/08f2e8ab9be4becc.js"].map(t=>e.l(t))).then(()=>t(788946)))},830938,e=>{e.v(t=>Promise.all(["static/chunks/69cb926df640b6f9.js"].map(t=>e.l(t))).then(()=>t(810229)))},828671,e=>{e.v(t=>Promise.all(["static/chunks/77aae7ead40f2c15.js"].map(t=>e.l(t))).then(()=>t(547256)))},670617,e=>{e.v(t=>Promise.all(["static/chunks/a7c316e64db81a7b.js"].map(t=>e.l(t))).then(()=>t(997739)))},271613,e=>{e.v(t=>Promise.all(["static/chunks/8fabc7ef6ac9614d.js"].map(t=>e.l(t))).then(()=>t(624622)))},496130,e=>{e.v(t=>Promise.all(["static/chunks/b77ce9ae1fd95d46.js"].map(t=>e.l(t))).then(()=>t(993197)))},361273,e=>{e.v(t=>Promise.all(["static/chunks/d451ff5c95eedb0d.js"].map(t=>e.l(t))).then(()=>t(628834)))},168644,e=>{e.v(t=>Promise.all(["static/chunks/c4a3d0fe0bf6ee2e.js"].map(t=>e.l(t))).then(()=>t(790392)))},643581,e=>{e.v(t=>Promise.all(["static/chunks/28c52cf01eb68739.js"].map(t=>e.l(t))).then(()=>t(34544)))},703169,e=>{e.v(t=>Promise.all(["static/chunks/0579995cb3430ad9.js"].map(t=>e.l(t))).then(()=>t(7216)))},903107,e=>{e.v(t=>Promise.all(["static/chunks/444e320398b2e1b4.js"].map(t=>e.l(t))).then(()=>t(595484)))},638530,e=>{e.v(t=>Promise.all(["static/chunks/0e8af9a0412ac1b0.js"].map(t=>e.l(t))).then(()=>t(741850)))},703064,e=>{e.v(t=>Promise.all(["static/chunks/130beb2def5c5952.js"].map(t=>e.l(t))).then(()=>t(376506)))},350794,e=>{e.v(t=>Promise.all(["static/chunks/2f6e2e4c2d03d66f.js"].map(t=>e.l(t))).then(()=>t(319804)))},798790,e=>{e.v(t=>Promise.all(["static/chunks/61d3a8105f978cec.js"].map(t=>e.l(t))).then(()=>t(401224)))},151536,e=>{e.v(t=>Promise.all(["static/chunks/69ddfccc8cf0be65.js"].map(t=>e.l(t))).then(()=>t(93620)))},432411,e=>{e.v(t=>Promise.all(["static/chunks/eb4e3ce14c8e5cdf.js"].map(t=>e.l(t))).then(()=>t(941307)))},164290,e=>{e.v(t=>Promise.all(["static/chunks/a08603f1f09be4c9.js"].map(t=>e.l(t))).then(()=>t(856819)))},939987,e=>{e.v(t=>Promise.all(["static/chunks/4600b6ad59d5a62f.js"].map(t=>e.l(t))).then(()=>t(981165)))},452694,e=>{e.v(t=>Promise.all(["static/chunks/b219cbddeb5838fe.js"].map(t=>e.l(t))).then(()=>t(238707)))},436068,e=>{e.v(t=>Promise.all(["static/chunks/4c90c042c93224fb.js"].map(t=>e.l(t))).then(()=>t(396828)))},25319,e=>{e.v(t=>Promise.all(["static/chunks/78a697829acbb082.js"].map(t=>e.l(t))).then(()=>t(923536)))},902302,e=>{e.v(t=>Promise.all(["static/chunks/065e5bff793312fa.js"].map(t=>e.l(t))).then(()=>t(369002)))},608878,e=>{e.v(t=>Promise.all(["static/chunks/dc17f623661a4dd5.js"].map(t=>e.l(t))).then(()=>t(138231)))},709729,e=>{e.v(t=>Promise.all(["static/chunks/e42839e80ff21ab3.js"].map(t=>e.l(t))).then(()=>t(998693)))},596894,e=>{e.v(t=>Promise.all(["static/chunks/e3cb5ec30322d74f.js"].map(t=>e.l(t))).then(()=>t(577803)))},551001,e=>{e.v(t=>Promise.all(["static/chunks/af824ac28bb86209.js"].map(t=>e.l(t))).then(()=>t(309353)))}]);