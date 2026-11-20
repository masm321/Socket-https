include win64.inc

include ksamd64.inc
include   Macros\x64macros.inc
include Macros\x64calling.inc
include Macros\IF_ELSEIF.inc
include		ws2_32.inc
include user32.inc
include kernel32.inc
;include shell32.inc
include comctl32.inc;
include comdlg32.inc
include ole32.inc
include gdi32.inc
include secur32.inc
include crypt32.inc
include zlibstat.inc

include oaidl.inc	;com
include shlobj.inc	;打开文件夹的对话框
include vfw32.inc;		;Video for Windows（VFW）;capCreateCaptureWindowA
include gdiplus.inc
;include avicap32.inc
;include winextra.inc
;include _BrowseFolder.asm 这里不能加入源码。要不在windbg调试过程中会停留在inc里，不能在asm里调试

include winmm.inc
include list-entry.inc
includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib ole32.lib
includelib gdi32.lib
includelib	ws2_32.lib
includelib Secur32.Lib
includelib zlibstat.lib
;includelib zlib.lib
includelib Crypt32.Lib

includelib Vfw32.Lib	;
includelib winmm.lib
includelib GdiPlus.lib	;GDI +支持的图形文件格式为BMP，GIF，JPEG，PNG，TIFF，Exif，WMF和EMF
;includelib avicap32.lib
;includelib libeay32.lib
;includelib ssleay32.lib

IDD_DIALOG			equ 1000

IDM_MENU			equ 10000
IDM_FILE_EXIT		equ 10001
IDM_HELP_ABOUT		equ 10101

WM_PLAYSOUND equ WM_USER+1
heap_recv_weather_size	equ 1024*1024*2
heap_send_face_size	equ 1024*1024*10
heap_recv_face_size	equ 1024*1024*10
heap_send_voice_size	equ 1024*1024*10
heap_recv_voice_size	equ 1024*1024*10

heap_recv_bitmap_size	equ 1024*1024*10
heap_send_bitmap_size	equ 1024*1024*10



cpu_count equ 8


  FP8 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL8 value
        .code
        EXITM <vname>
      ENDM



atext macro _name:REQ,_text:REQ,other:VARARG
	
	.data
	align 8
	_name db _text
	for _ehter:REQ,<other>
		db _ehter	;0d0ah
	endm	
	db 0
	.code
	exitm <_name>
endm

IFNDEF LastError

LastError MACRO
        IFNDEF @@_e_r_r_o_r_@@
          .data?
            @@_e_r_r_o_r_@@ db 1024 dup (?)
          .code
        ENDIF
       ; pushad
       ; pushfd
        invoke GetLastError
        mov r8,rax
        invoke FormatMessageA,FORMAT_MESSAGE_FROM_SYSTEM,0,r8,0,addr @@_e_r_r_o_r_@@,1024,NULL
       ; popfd
       ; popad
        EXITM <offset @@_e_r_r_o_r_@@>
ENDM

endif
GdiPlusBegin MACRO
      .data
        gdii GdiplusStartupInput <>
        GDItoken@@@@ dq ?
      .code
      mov gdii.GdiplusVersion, 1
      mov gdii.DebugEventCallback, 0
      mov gdii.SuppressBackgroundThread, 0
      mov gdii.SuppressExternalCodecs, 0
      invoke GdiplusStartup,ADDR GDItoken@@@@,ADDR gdii,0
    ENDM

    GdiPlusEnd MACRO
      invoke GdiplusShutdown,GDItoken@@@@        ; cleanup on exit
    ENDM
    
    
layersinfo struct 16		;神经网络的层数，我们是全连接
	playersinfo LIST_ENTRY <>	;每一个层的信息
	layer_in_layers	dq ?	;处在哪一层
	
	firstlayer	dq ?;第一层吗？
	endlayer	dq ?;最后一层吗？
	weight_count	dq ?;本层的权重参数计数
	
	weight_buffer_length_all 	dq ? 	;所有的分配的内存的总数
	
	pweight_buffer_list	LIST_ENTRY <?>;权重参数缓冲 是一个链表 lea memory_list_for_weight 比如第一层的权重为 80*80*80*80*8 = 312M，所以直接申请的话是不会成功的
	pweight_tidu_buffer_list	LIST_ENTRY <?>;权重梯度链表和权重缓冲区大小一样
	last_neure_cell_count dq ?;上层神经元计数
	neure_cell_count dq ?;本层神经元计数
	pneure_cell_buffer dq ?	;神经元缓冲区，一般的我们的位图是80*80 用双精度浮点表示 为80*80*8 = 51200字节 ,这里代表 激活值：g(z)
	
	pbias_buffer			dq ?	;偏置项
	
	pz_value_buffer			dq ?	;Z值 thta*x= Z	;它和神经元具有相同的个数
	
	pa_value_buffer		dq ?;激活值：g(z) 缓冲区
	
	pdelta_value_buffer	dq ?;本层神经元的中间误差
	
	z_value_all		dq ?
	a_value_all		dq ?
	delta_value_all		dq ?
	
layersinfo ends 
memory_list_for_weight struct		;权重要分配的内存有可能很大，最好使用链表

	_LIST_ENTRY LIST_ENTRY <?>;释放的时候也需要这个地址
	weight_buffer_Size	dq ?
	pweight_buffer dq ?	
	buffer		dq ?
	
memory_list_for_weight ends
thread_param struct
	
	pmemory_bitmap_buffer 			dq ?	;每个线程可以访问的灰度图链表
	pthread_layersinfo_LIST_ENTRY_buffer	dq ?		;线程创建的层链表指针
	hevent_for_done				dq ?		;本线程已经处理完毕的事件
	hevent_for_wait				dq ?		;本线程等待是否需要继续处理的事件
	
	_rect					RECT <?>
	child_id				dq ?
	jtheta					dq ?		;产生的jtheta
thread_param ends    
    
record_voice_struct struct
	hWin			dq ?
	hwaveout		dq ?
	wave_out_free		dq ?;查找一个可以使用的输出内存
	record_buffer 		dq ?
	record_buffer_length 	dq ?
	WAVEHDR_out_buffer1	dq ?
	WAVEHDR_out_buffer2	dq ?
	WAVEHDR_out_buffer3	dq ?
	WAVEHDR_out_buffer4	dq ?
	
	
record_voice_struct ends

s_hard_sample_src_dir_and_des_dir struct
	psrc_dir	dq ?
	
	pdes_dir dq ?
	
	sample_flags dq ?	;正负样本
	
s_hard_sample_src_dir_and_des_dir ends

.data
floadlimt_40		real8 0.40
floadlimt_50		real8 0.50
floadlimt_60		real8 0.60
floadlimt_65		real8 0.65
floadlimt_70		real8 0.70
floadlimt_80		real8 0.80
floadlimt_85		real8 0.85
floadlimt_90		real8 0.90
floadlimt_95		real8 0.95
floadlimt_98		real8 0.98
fload10000		real8 10000.0
fload20000		real8 20000.0
fload30000		real8 30000.0
fload50000		real8 50000.0
.const
backweigth_name_big					db "d:\weigth_big.hex",0
backweigth_name_small					db "d:\weigth_small.hex",0
backbias_name_small					db "d:\bias_small.hex",0
zlib_ver			db "1.2.11",0
camtitle		       db 'masm64WEBCAM'
ClassName			db 'DLGCLASS',0
AppName				db 'Dialog as main',0
AboutMsg			db 'MASM32 RadASM Dialog as main',13,10,'Copyright ?MASM32 2001',0
_messagebox_exit_proc		db "_messagebox_exit_proc",0
szFilter	db	'Bmp Files(*.bmp)',0,'*.bmp',0,'All Files(*.*)',0,'*.*',0,0
findfilename				db "\*.bmp",0
pcmfilename				db "\testrecoad.pcm",0
errorfilename				db "\error.txt",0

findfilename_format			db "%s\%s",0
findface_format				db "窗口ID%d，相似度%s",0
fujiafilename_format			db "%s\%s.txt",0
errorcount_format			db "%s  关键点错误次数%d",0dh,0ah,0
reconnectcount_format			db "重新连接次数%d",0
record_voice_length_format			db "录音长度%d",0
error_Grey				db "转换灰度图错误",0
bitmap_size_format			db "图像尺度:%d * %d",0
EncryptMessage_error_format		db "0 是send()错误，1是正确，其余值是EncryptMessage() 错误:代码%d",0
findfileerror				db "查找文件错误!",0
findfileerror1				db "查找文件错误1!",0
findfileerror2				db "查找文件错误2!",0
NO_MORE_FILES				db "所有文件已经查找完毕",0
NO_MORE_FILES1				db "所有文件已经查找完毕1",0
createfileerror				db "打开文件错误",0
readfileerror				db "读文件错误",0
errorcantnot_decrypt			db "发送待检测图片是不能解密服务端的关键点数据",0
createlandmarkerror			db "创建脸部关键点文件错误",0

createlogfileerror			db "创建错误日志记录文件失败",0
threadexit				db "线程退出了！",0

filetoolager				db "文件太大超过10M",0

sample_bitmap_fu_big				db "d:\负样本大",0
sample_bitmap_zheng_big				db "d:\正样本大",0
hard_sample_zheng_big				db "d:\未识别正样本",0
hard_sample_fu_big				db "d:\未识别负样本",0
hard_sample_zheng_small				db "d:\未识别小正样本",0
hard_sample_fu_small				db "d:\未识别小负样本",0
sample_bitmap_fu_small				db "d:\负样本",0
sample_bitmap_zheng_small			db "d:\正样本",0			
setdir_back_bmp					db "n:\face_bitmap_ok",0
setdir_landmake				db "n:\face_bitmap_ok_landmark",0
covbitmap				db "n:\bitmap80by80",0
createbackerror				db "创建备份文件错误",0
keepAlive				dd 1
keepIdle				dd 10000  ;//如果在10秒内没有任何数据交互,则进行探测. 缺省值:7200(smilliseconds == 10秒
keepInterval				dd 1000;//探测时发探测包的时间间隔为1秒. 缺省值:75(s)
keepCount 				dd  3;      //探测重试的次数. 全部超时则认定连接失效..缺省值:9(次)
;Content-Encoding: gzip		Content-Encodin:gzip 表示响应数据已被压缩
Transfer_Encoding		db "Transfer-Encoding: chunked"
				dw 0a0dh
			;	dw 0a0dh		;天地图网站没有这两个数据

Transfer_Encoding_size		EQU $ -Transfer_Encoding


chunked_end				db "0"
				dw 0a0dh
				dw 0a0dh
chunked_end_size		EQU $ -chunked_end			
				
access_token_token			db '"access_token":"',0;{"refresh_token":"25.8381901e2e1e7ac6d676322886ab3a83.315360000.1869313674.282335-15834241","expires_in":2592000,"session_ke

access_token_token_end_flags		db '","',0

error_message_success			db '"err_msg":"success."',0
result					db '"result":["',0
result_end_flags			db '"],',0


Content_Length 			db "Content-Length: ",0
Content_Encoding		db "Content-Encoding: ",0	
gzip_compress				db "gzip",0
deflate__compress			db "deflate",0			
API_Key				db "4abvsjVM4A80NmZXBPusQxAW",0
Secret_Key			db "9GlZwhDGHWzrunCHTZpUIl2C3vcH27Gn",0
errorsocket			db "errorsocket",0
again_connect			db "again_connect?",0
align 16
   ipbaidu			db "aip.baidubce.com",0;"39.156.66.110",0;aip.baidubce.com 图像识别令牌
   ipbaidu_voice_token		db "39.156.66.111",0;openapi.baidu.com 语音识别令牌
   ipbaidu_voice2text		db "39.156.66.99",0;vop.baidu.com;语音转汉字
   ipbaidu_text2voice		db "39.156.66.237",0;tsn.baidu.com汉字转语音
   ipbaidu_weather		db "112.34.111.148",0;api.map.baidu.com;地图和天气
  TargetName			db "aip.baidubce.com",0
  ipaddress			db "10.0.0.40",0
  align 16
  TargetName_wide		dw "a","i","p",".","b","a","i","d","u","b","c","e",".","c","o","m",0
  align 16
   TargetName_voiceandtext_token			db "openapi.baidu.com",0
  align 16
  TargetName_voiceandtext_token_wide		dw "o","p","e","n","a","p","i",".","b","a","i","d","u",".","c","o","m",0
  align 16
   TargetName_voice2text			db "vop.baidu.com",0
  align 16
   TargetName_voice2textwide		dw  "v","o","p",".","b","a","i","d","u",".","c","o","m",0
  align 16
    TargetName_text2voice			db "tsn.baidu.com",0
  align 16
   TargetName_textwide2voice		dw  "t","s","n",".","b","a","i","d","u",".","c","o","m",0
  align 16
   TargetName_weather			db "api.map.baidu.com",0
  align 16
   TargetName_weathertwide		dw "a","p","i",".","m","a","p",".","b","a","i","d","u",".","c","o","m",0
  align 16
sspi				db "Microsoft Unified Security Protocol Provider",0


align 16
;https://api.map.baidu.com/telematics/v3/weather?output=json&ak=nGXHgIDgGX8xyqgWu4LuYE4Rzywhgyg3&callback=getTodayWeather&location=120.38,36
https_for_baidu_weather		db 'GET /telematics/v3/weather?output=json&ak=nGXHgIDgGX8xyqgWu4LuYE4Rzywhgyg3&location=120.24,36.5 HTTP/1.1'
				dw 0a0dh
				db 'Host: api.map.baidu.com'
				dw 0a0dh
				db 'Accept-Encoding: gzip, deflate';表示客户端支持gzip
				dw 0a0dh
				db 'Cache-Control: no-cache'
				dw 0a0dh
				db 'Connection: keep-alive';这里小写也可以 Keep-Alive
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko';AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36';该头域的内容包含发出请求的用户信息。 
				dw 0a0dh
				db 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
			;	dw 0a0dh
			;	db 'Accept-Language: zh-CN,zh'
			;	db 'Accept: text/html, application/xhtml+xml, */*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
				dw 0a0dh
				dw 0a0dh
				db 0
				
https_for_baidu_weather_size	equ $-	https_for_baidu_weather				
align 16	
;format_https_for_baidu_weather_image			
format_https_for_baidu_weather_image	db 'GET %s HTTP/1.1'
				dw 0a0dh
				db 'Host: api.map.baidu.com'
				dw 0a0dh
				db 'Accept-Encoding: gzip, deflate';表示客户端支持gzip
				dw 0a0dh
				db 'Cache-Control: no-cache'
				dw 0a0dh
				db 'Connection: keep-alive'
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/533.36 (KHTML, like Gecko) Chrome/77.0.3865.120 Safari/533.36';AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36';该头域的内容包含发出请求的用户信息。 
				dw 0a0dh
				;db 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
			;	dw 0a0dh
			;	db 'Accept-Language: zh-CN,zh'
				db 'Accept: text/html, application/xhtml+xml, */*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
				dw 0a0dh
				dw 0a0dh
				db 0
				
format_https_for_baidu_weather_image_size 	equ $-format_https_for_baidu_weather_image					
  align 16
;https_for_baidu		db "GET /oauth/2.0/token HTTP/1.1"		;sizeof 检测不正确，它只能单行
https_for_baidu_face_token			db 'POST /oauth/2.0/token?grant_type=client_credentials&client_id=4abvsjVM4A80NmZXBPusQxAW&client_secret=9GlZwhDGHWzrunCHTZpUIl2C3vcH27Gn HTTP/1.1'
				dw 0a0dh
				db 'Host: aip.baidubce.com'
				dw 0a0dh
				db 'Accept: text/html, application/xhtml+xml, */*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko';AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36';该头域的内容包含发出请求的用户信息。 
			
				dw 0a0dh
				
			;	db "Content-Type: application/json"
			;	dw 0a0dh
				db 'Accept-Encoding: gzip, deflate'	;表示客户端支持gzip
			;	db 'Accept-Encoding: deflate'
				dw 0a0dh
				db 'Accept-Language: zh-CN'
				dw 0a0dh
				db 'Connection: Keep-Alive'
				
				dw 0a0dh
				dw 0a0dh
				
https_for_baidu_face_token_size EQU $ -https_for_baidu_face_token

https_for_baidu_voice_token		db 'POST /oauth/2.0/token?grant_type=client_credentials&client_id=V5e6ll68RQF9SAYYBOvNg6Ky&client_secret=HFSwS79LL3DBlZCPo71m8VTE0qo84316 HTTP/1.1'
				dw 0a0dh
				db 'Host: openapi.baidu.com'
				dw 0a0dh
				db 'Accept: text/html, application/xhtml+xml, */*';告诉WEB服务器自己接受什么介质类型，/ 表示任何类型
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko';AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36';该头域的内容包含发出请求的用户信息。 
			
				dw 0a0dh
				
			;	db "Content-Type: application/json"
			;	dw 0a0dh
				db 'Accept-Encoding: gzip, deflate'	;表示客户端支持gzip
			;	db 'Accept-Encoding: deflate'
				dw 0a0dh
				db 'Accept-Language: zh-CN'
				dw 0a0dh
				db 'Connection: Keep-Alive'
				
				dw 0a0dh
				dw 0a0dh
				
https_for_baidu_voice_token_size EQU $ -https_for_baidu_voice_token


format_https_for_baidu_voice2text 	db "POST /server_api?dev_pid=1536&cuid=123456789asdfgh&token=%s HTTP/1.1"
				dw 0a0dh
				db 'Host: vop.baidu.com'
				
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.2.3) Gecko/20100401 firefox/3.6.3'
				
				dw 0a0dh
				
				db "Content-Type: audio/pcm; rate=16000" 
			;	db "Content-Type: application/x-www-form-urlencoded"
				dw 0a0dh
				db 'Accept-Encoding: gzip'	;表示客户端支持gzip
			;	db 'Accept-Encoding: deflate'	;表示客户端支持gzip
				dw 0a0dh
				
			;	db "Transfer-Encoding: chunked"
			;	dw 0a0dh
			;	db "Vary: Accept-Encoding"
			;	dw 0a0dh
			;	db "cache-control: no-cache"
			;	dw 0a0dh
				
			
				
				db "Content-Encoding: gzip";指文档的编码（Encode）方法。 
			

				dw 0a0dh
				
				db 'Connection: Keep-Alive'
				
				dw 0a0dh
			;	db 'Accept: */*'
			;	dw 0a0dh
				
				
			;	db 'Connection:close'
				db 'content-Length: %d'
				
				
				
				dw 0a0dh
				dw 0a0dh
				
				db 0
				db "%s"	;这里是分块大小，就是JSON的压缩后大小
				dw 0a0dh
					;;;;;这里是压缩的数据
					
				db 0	

format_https_for_baidu_text2voice db "POST /text2audio HTTP/1.1"
				dw 0a0dh
				db 'Host: tsn.baidu.com'
				
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.2.3) Gecko/20100401 firefox/3.6.3'
				
				dw 0a0dh
				
				db "Content-Type: audio/pcm; rate=16000" 
			;	db "Content-Type: application/x-www-form-urlencoded"
				dw 0a0dh
				db 'Accept-Encoding: gzip'	;表示客户端支持gzip
			;	db 'Accept-Encoding: deflate'	;表示客户端支持gzip
				dw 0a0dh
				
			;	db "Transfer-Encoding: chunked"
			;	dw 0a0dh
			;	db "Vary: Accept-Encoding"
			;	dw 0a0dh
			;	db "cache-control: no-cache"
			;	dw 0a0dh
				
			
				
				db "Content-Encoding: gzip";指文档的编码（Encode）方法。 
			

				dw 0a0dh
				
				db 'Connection: Keep-Alive'
				
				dw 0a0dh
			;	db 'Accept: */*'
			;	dw 0a0dh
				
				
			;	db 'Connection:close'
				db 'content-Length: %d'
				
				
				
				dw 0a0dh
				dw 0a0dh
				db 0
				
format_https_for_baidu_text2voice_body	db "per=0&aue=4&lan=zh&ctp=1&cuid=123456789asdfgh&tok=%s&tex=%s",0
				
	;https://tsn.baidu.com/text2audio?tex=%E4%B8%AD%E5%8D%8E%E4%BA%BA%E6%B0%91%E5%85%B1%E5%92%8C%E5%9B%BD%E6%98%AF%E6%88%91%E4%BB%AC%E7%9A%84%E7%A5%96%E5%9B%BD&aue=6&lan=zh&cuid=1234565789&ctp=1&tok=24.765c4532e59fbfba829329546d36cde1.2592000.1576828601.282335-17715121			
					
				


					
					
					
					
					
					
					
					
					

format_https_for_baidu_face_detector 	db "POST /rest/2.0/face/v3/detect?access_token=%s HTTP/1.1"
				dw 0a0dh
				db 'Host: aip.baidubce.com'
				
				dw 0a0dh
				db 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.2.3) Gecko/20100401 firefox/3.6.3'
				
				dw 0a0dh
				
				db "Content-Type:application/json"; charset=UTF-8";实体头用于向接收方指示实体的介质类型。 
			;	db "Content-Type: application/x-www-form-urlencoded"
				dw 0a0dh
				db 'Accept-Encoding: gzip'	;表示客户端支持gzip
			;	db 'Accept-Encoding: deflate'	;表示客户端支持gzip
				dw 0a0dh
				
			;	db "Transfer-Encoding: chunked"
			;	dw 0a0dh
			;	db "Vary: Accept-Encoding"
			;	dw 0a0dh
			;	db "cache-control: no-cache"
			;	dw 0a0dh
				
			
				
				db "Content-Encoding: gzip";指文档的编码（Encode）方法。 
			

				dw 0a0dh
				
				db 'Connection: Keep-Alive'
				
				dw 0a0dh
			;	db 'Accept: */*'
			;	dw 0a0dh
				
				
			;	db 'Connection:close'
				db 'content-Length: %d'
				
				
				
				dw 0a0dh
				dw 0a0dh
				
				db 0
				db "%s"	;这里是分块大小，就是JSON的压缩后大小
				dw 0a0dh
					;;;;;这里是压缩的数据
					
				db 0	
				;实体可以是一个经过编码的字节流，它的编码方式由Content-Encoding或Content-Type定 义，它的长度由Content-Length或Content-Range定义。
bbbb			db "25.ec7fb65c707ca9be5ab5e1277ad2d363.315360000.1868989937.282335-15834241",0
format_json			db '{"image_type":"BASE64","face_field":"age,beauty,expression,face_shape,gender,glasses,landmark,landmark72,landmark150,race,quality,eye_status,emotion","image":"',0
			;	db '{"image_type":"BASE64","image":"qwe78rttfd"}',0


base64chars			db  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",0










format_Content_Length_view	db "Content_Length: %d",0
Server_Authentication 		db "1.3.6.1.5.5.7.3.1",0
ssleay32			db "ssleay32.dll",0
SSL_library_init_text		db "SSL_library_init",0
SSL_load_error_strings_text	db "SSL_load_error_strings",0
SSLv3_client_method_text	db "SSLv3_client_method",0
SSLv23_client_method_text	db "SSLv23_client_method",0
SSL_CTX_new_text		db "SSL_CTX_new",0
SSL_new_text			db "SSL_new",0
SSL_connect_text		db "SSL_connect",0
SSL_write_text			db "SSL_write",0
SSL_read_text			db "SSL_read",0
SSL_free_text			db "SSL_free",0
SSL_CTX_free_text		db "SSL_CTX_free",0
SSL_shutdown_text		db "SSL_shutdown",0
SSL_set_fd_text			db "SSL_set_fd",0

landmark150			db '"landmark150":',0

x_flags				db '{"x":',0
y_flags				db '"y":',0

cheek_right_1			db '"cheek_right_1":',0
cheek_right_3			db '"cheek_right_3":',0
cheek_right_5			db '"cheek_right_5":',0
cheek_right_7			db '"cheek_right_7":',0
cheek_right_9			db '"cheek_right_9":',0
cheek_right_11			db '"cheek_right_11":',0

chin_2				db '"chin_2"',0

cheek_left_11			db '"cheek_left_11":',0
cheek_left_9			db '"cheek_left_9":',0
cheek_left_7			db '"cheek_left_7":',0
cheek_left_5			db '"cheek_left_5":',0
cheek_left_3			db '"cheek_left_3":',0
cheek_left_1			db '"cheek_left_1":',0

eye_right_corner_right		db '"eye_right_corner_right":',0
eye_right_eyelid_upper_2	db '"eye_right_eyelid_upper_2":',0
eye_right_eyelid_upper_4	db '"eye_right_eyelid_upper_4":',0
eye_right_eyelid_upper_6	db '"eye_right_eyelid_upper_6":',0

eye_right_corner_left		db '"eye_right_corner_left":',0
eye_right_eyelid_lower_6	db '"eye_right_eyelid_lower_6":',0
eye_right_eyelid_lower_4	db '"eye_right_eyelid_lower_4":',0
eye_right_eyelid_lower_2	db '"eye_right_eyelid_lower_2":',0
eye_right_eyeball_center	db '"eye_right_eyeball_center":',0
eyebrow_right_corner_right	db '"eyebrow_right_corner_right":',0

eyebrow_right_upper_2		db '"eyebrow_right_upper_2":',0
eyebrow_right_upper_3		db '"eyebrow_right_upper_3":',0

eyebrow_right_corner_left	db '"eyebrow_right_corner_left":',0

eyebrow_right_lower_3		db '"eyebrow_right_lower_3":',0
eyebrow_right_lower_2		db '"eyebrow_right_lower_2":',0
eyebrow_right_lower_1		db '"eyebrow_right_lower_1":',0

eye_left_corner_right		db '"eye_left_corner_right":',0

eye_left_eyelid_upper_2		db '"eye_left_eyelid_upper_2":',0
eye_left_eyelid_upper_4		db '"eye_left_eyelid_upper_4":',0
eye_left_eyelid_upper_6		db '"eye_left_eyelid_upper_6":',0

eye_left_corner_left		db '"eye_left_corner_left":',0
eye_left_eyelid_lower_6		db '"eye_left_eyelid_lower_6":',0
eye_left_eyelid_lower_4		db '"eye_left_eyelid_lower_4":',0
eye_left_eyelid_lower_2		db '"eye_left_eyelid_lower_2":',0

eyebrow_left_corner_right	db '"eyebrow_left_corner_right":',0

eyebrow_left_upper_2		db '"eyebrow_left_upper_2":',0
eyebrow_left_upper_3		db '"eyebrow_left_upper_3":',0
eyebrow_left_upper_4		db '"eyebrow_left_upper_4":',0

eyebrow_left_corner_left	db '"eyebrow_left_corner_left":',0
eyebrow_left_lower_3		db '"eyebrow_left_lower_3":',0
eyebrow_left_lower_2		db '"eyebrow_left_lower_2":',0
eyebrow_left_lower_1		db '"eyebrow_left_lower_1":',0

nose_right_contour_1		db '"nose_right_contour_1":',0
nose_right_contour_2		db '"nose_right_contour_2":',0
nose_right_contour_3		db '"nose_right_contour_3":',0
nose_right_contour_4		db '"nose_right_contour_4":',0
nose_right_contour_6		db '"nose_right_contour_6":',0

nose_left_contour_6		db '"nose_left_contour_6":',0
nose_left_contour_4		db '"nose_left_contour_4":',0
nose_left_contour_3		db '"nose_left_contour_3":',0
nose_left_contour_2		db '"nose_left_contour_2":',0
nose_left_contour_1		db '"nose_left_contour_1":',0

nose_tip			db '"nose_tip":',0

mouth_corner_right_outer	db '"mouth_corner_right_outer":',0

mouth_lip_upper_outer_3		db ',"mouth_lip_upper_outer_3":',0
mouth_lip_upper_outer_6		db ',"mouth_lip_upper_outer_6":',0
mouth_lip_upper_outer_9		db ',"mouth_lip_upper_outer_9":',0

mouth_corner_left_outer		db '"mouth_corner_left_outer":',0

mouth_lip_lower_outer_9		db '"mouth_lip_lower_outer_9":',0
mouth_lip_lower_outer_6		db '"mouth_lip_lower_outer_6":',0
mouth_lip_lower_outer_3		db '"mouth_lip_lower_outer_3":',0

mouth_lip_upper_inner_3		db '"mouth_lip_upper_inner_3":',0
mouth_lip_upper_inner_6		db '"mouth_lip_upper_inner_6":',0
mouth_lip_upper_inner_9		db '"mouth_lip_upper_inner_9":',0

mouth_lip_lower_inner_9		db '"mouth_lip_lower_inner_9":',0
mouth_lip_lower_inner_6		db '"mouth_lip_lower_inner_6":',0
mouth_lip_lower_inner_3		db '"mouth_lip_lower_inner_3":',0

cheek_right_2			db '"cheek_right_2":',0
cheek_right_4			db '"cheek_right_4":',0
cheek_right_6			db '"cheek_right_6":',0
cheek_right_8			db '"cheek_right_8":',0
cheek_right_10			db '"cheek_right_10":',0
chin_1				db '"chin_1":',0
chin_3				db '"chin_3":',0

cheek_left_10			db '"cheek_left_10":',0
cheek_left_8			db '"cheek_left_8":',0
cheek_left_6			db '"cheek_left_6":',0
cheek_left_4			db '"cheek_left_4":',0
cheek_left_2			db '"cheek_left_2":',0
eyebrow_right_upper_1		db '"eyebrow_right_upper_1":',0
eyebrow_right_upper_5		db '"eyebrow_right_upper_5":',0
eyebrow_left_upper_1		db '"eyebrow_left_upper_1":',0
eyebrow_left_upper_5		db '"eyebrow_left_upper_5":',0

eye_right_eyelid_upper_1	db '"eye_right_eyelid_upper_1":',0
eye_right_eyelid_upper_3	db '"eye_right_eyelid_upper_3":',0
eye_right_eyelid_upper_5	db '"eye_right_eyelid_upper_5":',0
eye_right_eyelid_upper_7	db '"eye_right_eyelid_upper_7":',0

eye_right_eyelid_lower_7	db ',"eye_right_eyelid_lower_7":',0
eye_right_eyelid_lower_5	db ',"eye_right_eyelid_lower_5":',0
eye_right_eyelid_lower_3	db ',"eye_right_eyelid_lower_3":',0
eye_right_eyelid_lower_1	db ',"eye_right_eyelid_lower_7":',0

eye_right_eyeball_right		db '"eye_right_eyeball_right":',0
eye_right_eyeball_left		db '"eye_right_eyeball_left":',0

eye_left_eyelid_upper_1		db '"eye_left_eyelid_upper_1":',0
eye_left_eyelid_upper_3		db '"eye_left_eyelid_upper_3":',0
eye_left_eyelid_upper_5		db '"eye_left_eyelid_upper_5":',0
eye_left_eyelid_upper_7		db '"eye_left_eyelid_upper_7":',0

eye_left_eyelid_lower_7		db '"eye_left_eyelid_lower_7":',0
eye_left_eyelid_lower_5		db '"eye_left_eyelid_lower_5":',0
eye_left_eyelid_lower_3		db '"eye_left_eyelid_lower_3":',0
eye_left_eyelid_lower_1		db '"eye_left_eyelid_lower_1":',0

eye_left_eyeball_right		db '"eye_left_eyeball_right":',0
eye_left_eyeball_left		db '"eye_left_eyeball_left"',0

nose_bridge_1			db '"nose_bridge_1"',0
nose_bridge_2			db '"nose_bridge_2"',0
nose_bridge_3			db '"nose_bridge_3"',0


nose_right_contour_5		db '"nose_right_contour_5":',0
nose_right_contour_7		db '"nose_right_contour_7":',0
nose_left_contour_7		db '"nose_left_contour_7":',0
nose_left_contour_5		db '"nose_left_contour_5":',0
nose_middle_contour		db '"nose_middle_contour":',0
mouth_corner_right_inner	db '"mouth_corner_right_inner":',0
mouth_corner_left_inner		db '"mouth_corner_left_inner":',0

mouth_lip_upper_outer_1		db '"mouth_lip_upper_outer_1":',0
mouth_lip_upper_outer_2		db '"mouth_lip_upper_outer_2":',0
mouth_lip_upper_outer_4		db '"mouth_lip_upper_outer_4":',0
mouth_lip_upper_outer_5		db '"mouth_lip_upper_outer_5":',0
mouth_lip_upper_outer_7		db '"mouth_lip_upper_outer_7":',0
mouth_lip_upper_outer_8		db '"mouth_lip_upper_outer_8":',0
mouth_lip_upper_outer_10	db '"mouth_lip_upper_outer_10":',0
mouth_lip_upper_outer_11	db '"mouth_lip_upper_outer_11":',0

mouth_lip_lower_outer_11	db '"mouth_lip_lower_outer_11":',0
mouth_lip_lower_outer_10	db '"mouth_lip_lower_outer_10":',0
mouth_lip_lower_outer_8		db '"mouth_lip_lower_outer_8":',0
mouth_lip_lower_outer_7		db '"mouth_lip_lower_outer_7":',0
mouth_lip_lower_outer_5		db '"mouth_lip_lower_outer_5":',0
mouth_lip_lower_outer_4		db '"mouth_lip_lower_outer_4":',0
mouth_lip_lower_outer_2		db '"mouth_lip_lower_outer_2":',0
mouth_lip_lower_outer_1		db '"mouth_lip_lower_outer_1":',0


mouth_lip_upper_inner_1		db '"mouth_lip_upper_inner_1":',0
mouth_lip_upper_inner_2		db '"mouth_lip_upper_inner_2":',0
mouth_lip_upper_inner_4		db '"mouth_lip_upper_inner_4":',0
mouth_lip_upper_inner_5		db '"mouth_lip_upper_inner_5":',0
mouth_lip_upper_inner_7		db '"mouth_lip_upper_inner_7":',0
mouth_lip_upper_inner_8		db '"mouth_lip_upper_inner_8":',0
mouth_lip_upper_inner_10	db '"mouth_lip_upper_inner_10":',0
mouth_lip_upper_inner_11	db '"mouth_lip_upper_inner_11":',0

mouth_lip_lower_inner_11	db '"mouth_lip_lower_inner_11"',0
mouth_lip_lower_inner_10	db '"mouth_lip_lower_inner_10"',0
mouth_lip_lower_inner_8		db '"mouth_lip_lower_inner_8"',0
mouth_lip_lower_inner_7		db '"mouth_lip_lower_inner_7"',0
mouth_lip_lower_inner_5		db '"mouth_lip_lower_inner_5"',0
mouth_lip_lower_inner_4		db '"mouth_lip_lower_inner_4"',0
mouth_lip_lower_inner_2		db '"mouth_lip_lower_inner_2"',0
mouth_lip_lower_inner_1		db '"mouth_lip_lower_inner_1"',0



readfile_pic_error		db "addr readfile_pic_error",0

nopicture			db "nopicture",0

picname				db "\resizepic.bmp",0
downtimeout			db "获取服务端人脸检测数据超时继续等待？",0

nDevice   	 dq  0	       ; Device Number -> It can range from 0 through 9
  nFPS	     	dq 33       ; Frames per second. Must be 1000/FPS. E.g. 20 FPS = 50 milliseconds 毫秒;千分之一秒  Rate, in milliseconds
.data?
pbitmap_buffer_detector_ok		dq ?
hlock_read_write			dq ?
hard_sample_src_dir_and_des_dir		s_hard_sample_src_dir_and_des_dir <?>
hevent_ai				dq ?	;通知进行人脸检测的事件
hevent_continue_video			dq ?
pbitmap_for_face_detector		dq ?
dc_compatible				dq ?
dc_org					dq ?
wave_VHDR_KEYFRAM_count			dq ?
heap_send_with_EncryptMessage		dq ?

CredHandle_face			dq 10h dup (?)
CtxtHandle_face			dq 10h dup (?)
timstamp_face			dq 10h dup (?)

CredHandle_weather			dq 10h dup (?);A pointer to a CredHandle structure to receive the credential handle.
CtxtHandle_weather			dq 10h dup (?)
timstamp_weather			dq 10h dup (?)

CredHandle_voice2text			dq 10h dup (?)
CtxtHandle_voice2text			dq 10h dup (?)
timstamp_voice2text			dq 10h dup (?)

CredHandle_text2voice			dq 10h dup (?)
CtxtHandle_text2voice			dq 10h dup (?)
timstamp_text2voice			dq 10h dup (?)





pheap_send_weather_with_EncryptMessage	dq ?;天气数据加密发送服务端时需要的缓冲区
pheap_send_weather_with_EncryptMessage_length dq ?
pheap_recv_weather_with_EncryptMessage	dq ?	;;天气数据解密后从送服务端接收时需要的缓冲区
pheap_recv_weather_with_EncryptMessage_length	dq ?
pheap_recv_weather_with_ungzip_EncryptMessage	dq ?	;天气数据解密后再解压缩时需要的缓冲区
pheap_recv_weather_with_ungzip_EncryptMessage_length	dq ?

pheap_send_face_with_send			dq ?
pheap_send_face_with_EncryptMessage		dq ?
pheap_recv_face_with_EncryptMessage	dq ?	
pheap_recv_face_with_EncryptMessage_length	dq ?
pheap_recv_face_with_ungzip_EncryptMessage	dq ?	
pheap_recv_face_with_ungzip_EncryptMessage_length	dq ?





pheap_send_voice2text_with_send			dq ?	;发送的时候用的;因为语音数据是不定长的，所以不能固定，只能申请个大一点的
pheap_send_voice2text_with_EncryptMessage	dq ?
pheap_send_voice2text_with_EncryptMessage_length dq ?
pheap_recv_voice2text_with_EncryptMessage	dq ?	
pheap_recv_voice2text_with_EncryptMessage_length	dq ?
pheap_recv_voice2text_with_ungzip_EncryptMessage	dq ?	
pheap_recv_voice2text_with_ungzip_EncryptMessage_length	dq ?






pheap_send_text2voice_with_send			dq ?	;发送的时候用的;因为文字数据是不定长的，所以不能固定，并且要转换成UTF-8 只能申请个大一点的
pheap_send_text2voice_with_EncryptMessage	dq ?
pheap_send_text2voice_with_EncryptMessage_length dq ?
pheap_recv_text2voice_with_EncryptMessage	dq ?	
pheap_recv_text2voice_with_EncryptMessage_length	dq ?
pheap_recv_text2voice_with_ungzip_EncryptMessage	dq ?	
pheap_recv_text2voice_with_ungzip_EncryptMessage_length	dq ?



hSocket_face_token		dq ?
hSocket_face				dq ?
hSocket_voice_token		dq ?;语音类令牌
hSocket_voice			dq ?;语音类
hSocket_text2voice		dq ?
hSocket_weather			dq ?
pvoice_baidu_buffer		dq ?;10秒缓冲区指针
current_pos_baidu		dq ?;10秒缓冲区指针 有效数据长度
hWebcam				dq ?
hevent				dq ?
hthread				dq ?
errorcount			dq ?	;关键点检测失败计数
tcp_keepalive_in_buffer		tcp_keepalive <?>
align 16
tcp_keepalive_out_buffer		tcp_keepalive <?>
align 16
pheap_video_bitmap_buffer	dq ?
video_bitmap_buffer_size	dq ?
hDIBitmap_video			dq ?
phbitmap_wheater_buffer		dq ?
bitmap_weather_width		dq ?
bitmap_weather_higth		dq ?
hDIBitmap_weather		dq ?
hwavein				dq ?;波形输入句柄
hwaveout				dq ?;波形输出句柄
WAVEFORMATEX_buffer		WAVEFORMATEX <?>
WAVEFORMATEX_out_buffer		WAVEFORMATEX <?>
align 16
WAVEHDR_buffer1			WAVEHDR <?>
WAVEHDR_buffer2			WAVEHDR <?>
WAVEHDR_out_buffer1		WAVEHDR <?>
WAVEHDR_out_buffer2		WAVEHDR <?>
WAVEHDR_out_buffer3		WAVEHDR <?>
WAVEHDR_out_buffer4		WAVEHDR <?>
WAVEHDR_out_buffer5		WAVEHDR <?>
WAVEHDR_out_buffer_text2voice		WAVEHDR <?>
record_voice_struct_buffer		record_voice_struct <?>
__SYSTEMTIME			_SYSTEMTIME <>
hevent_wave_out		dq ?
szDeviceName			db 80 dup (?)
szDeviceVersion			db 80 dup (?)

			db	MAX_PATH dup (?)	;通用对话框获取的目录
DROPFILEBUFFER 			db	MAX_PATH dup (?)

temp_currentdir		db	MAX_PATH dup (?)
error_currentdir		db	MAX_PATH dup (?)
hfile_log			dq ?

keyword_buffer			db 80h dup (?)
dayPictureUrl			db 80h dup (?)
nightPictureUrl			db 80h dup (?)


tagCaptureParms_buffer	tagCaptureParms <?>
BITMAPINFO_buffer		BITMAPINFOHEADER <>;BITMAPINFO <>

align 16
pheap_Drag_pic_buffer		dq ?
pbitmap_for_drawpiont_back	dq ?
pbitmap_for_neural_network	dq ?
pbitmap_for_neural_network_mid	dq ?
pbitmap_for_neural_network_Grey dq ?
j_theta				dq ?;损失值
hfile_Drag_pic			dq ?
file_Drag_pic_size		dq ?
hDIBitmap_drawpoint		dq ?
pbitmap_for_drawpiont		dq ?
hSSL_new			dq ?
hSSL_CTX_new			dq ?
hssl_method			dq ?	
SSL_shutdown			dq ?
SSL_set_fd			dq ?
SSL_library_init		dq ?
SSL_load_error_strings		dq ?
SSLv23_client_method		dq ?
SSLv3_client_method		dq ?
SSL_CTX_new			dq ?
SSL_new				dq ?
SSL_connect			dq ?
SSL_write			dq ?
SSL_read			dq ?
SSL_free			dq ?
SSL_CTX_free			dq ?
hlibrary			dq ?


phChainEngine			dq ?
ssl_ctx				dq ?
ssl				dq ?
ssl_method			dq ?


converturlcode_length		dq ?

bitmap_base_length_utf8		dq ?
utf_8_wide_buffer		dq ?




bitmap_base_length		dq ?
hheap				dq ?
bitmapbufferfor_base64		dq ?
hDIBitmap_youyou		dq ?
dc_youyou			dq ?
sizeofbitmap_youyou		dq ?
hresinfo_youyou			dq ?
resource_bitmap_youyou		dq ?
token_buffer_face			db 4000h dup (?)
token_length			dq ?
token_voice_buffer			db 4000h dup (?)
token_buffer_text2voice			db 4000h dup (?)
token_buffer_vioce2text			db 4000h dup (?)

hInstance			dq ?
CommandLine			dq ?
hWnd				dq ?
hWnd_main			dq ?
align 16

align 16

temp_buffer_			dq 10h dup (?)



align 16
;precv_buffer				db 4000h dup (?)		;解压GZIP后的数据
;DecryptMessage_ok_buffer		db 4000h dup (?);已经解密好的数据缓冲区,也就是包含GZIP格式的信息


wave_out_free dq ?		;标记有效的音频输出缓冲区