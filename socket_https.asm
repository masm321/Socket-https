option casemap:none
OPTION DOTNAME

include socket_https.inc
public connect_server_for_https
public EncryptMessage_and_send
public wait_and_recv_data_for_https
public disconnect_server_for_https
public uncommpress_png
public _recv
public _send
public connect_server_for_8080
public connect_server_with_ipv6
PROTO64 external,logout,:QWORD,:QWORD
.data
 _keepAlive 	dd  		1; // 开启keepalive属性
 _keepIdle 	dd  		60; // 如该连接在60秒内没有任何数据往来,则进行探测
 _keepInterval 	dd  		5; // 探测时发包的时间间隔为5 秒
 _keepCount 	dd 		3; // 探测尝试的次数.如果第1次探测包就收到响应了,则后2次的不再发.


.data?

input_SecBuffer_buffer2		_SecBuffer <?>
align 16

recv_token_buffer					db 4000h dup (?);这个缓冲接收服务器返回的令牌


temp_buffer_for_list_zzz		db 5*_SecBuffer dup (?)

align 16
;deccount				dq ?
align 16
z_stream_buffer				z_stream <?>

CERT_CHAIN_ENGINE_CONFIG_buffer		CERT_CHAIN_ENGINE_CONFIG <?>

CERT_CHAIN_PARA_buffer			CERT_CHAIN_PARA <?>

CERT_CHAIN_POLICY_PARA_buffer		CERT_CHAIN_POLICY_PARA <?>

HTTPSPolicyCallbackData_buffer		HTTPSPolicyCallbackData <>

CERT_CHAIN_POLICY_STATUS_buffer		CERT_CHAIN_POLICY_STATUS <?>

.code

_HostnameToIP	proc	<:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _lpszHostName:qword
		local	@szBuffer[256]:byte
		local	@dwIP:dword
		mov _lpszHostName,rcx
		sub rsp,40h
		invoke	inet_addr,_lpszHostName
		.if	<<cmp eax,INADDR_NONE>>,nozero?
;********************************************************************
; 输入的是IP地址
;********************************************************************
			mov	@dwIP,eax
			
		.else
;********************************************************************
; 输入的是主机名称
;********************************************************************
			
			invoke	gethostbyname,_lpszHostName
			.if	<<test rax,rax>>,greater?
				xor	edi,edi		;用edi做计数器
				mov	rsi,[rax+hostent.h_list]
				.while	<<cmp qword ptr [rsi],0>>,nozero?
					mov	rbx,[rsi]
					mov eax,[rbx]
					mov	@dwIP,eax
					inc	rdi
					add	rsi,4
					.break
				.endw
			.else
				xor	eax,eax
				ret
			.endif
		.endif
		
		mov	eax,@dwIP
		add rsp,40h
		ret

_HostnameToIP	endp

_recv proc <:qword,:qword,:qword,:qword> uses rbx rsi rdi r12 r13 r14 r15 _hSocket:qword,_ipbuffer:qword,_size:qword,_flags:qword
	LOCAL @sizecount:qword
	LOCAL @ipbuffer:qword 
	LOCAL @timecount:qword
	
	mov _hSocket,rcx
	mov _ipbuffer,rdx
	mov _size,r8
	mov _flags,r9		;如果flags  为1 无需等待 没有数据就直接返回，因为是用ioctlsocket 获取到缓冲区有数据时才调用的
	sub rsp,40h
	
	mov @timecount,0
	mov rax,_ipbuffer
	mov @ipbuffer,rax
	
	
	mov rax,_size
	mov @sizecount,rax
	zzzz:
	
		.while   <<cmp @sizecount,0>>,GREATER?
			invoke recv ,_hSocket,@ipbuffer,@sizecount,0; 包含flags标志位的结构数据发送服务器  若无错误发生，recv()返回读入的字节数。如果连接已中止，返回0。否则的话，返回SOCKET_ERROR错误，应用程序可通过WSAGetLastError()获取相应错误代码。
										; 在阻塞模式下recv，recvfrom操作将会阻塞到缓冲区里有至少一个字节（TCP）或者一个完整的UDP数据报才返回。
    										;在没有数据到来时，对它们的调用都将处于睡眠状态，不会返回。
			.if	<<cmp eax,SOCKET_ERROR>>,zero?
				.if << cmp _flags,1>>,zero?
					mov eax,0
					add rsp,40h
					ret
				.endif
				invoke	WSAGetLastError
				.if <<cmp eax, WSAEWOULDBLOCK>>,zero?
					invoke Sleep,64h ;延时重发
					.if <<cmp @timecount ,20>>,greater?
						mov eax,0
						add rsp,40h
						ret
					.else 
						inc @timecount
					.endif
				.else
					mov eax,0
					add rsp,40h
					ret
				.endif
			.elseif <<test eax,eax>>,zero? ;如果连接已中止，返回0
				add rsp,40h
				ret	
				
			.else	;若无错误发生，recv()返回读入的字节数
				
				add @ipbuffer,rax
				sub @sizecount,rax
				mov @timecount,0
			.endif
		.endw
		mov eax,1
	
	add rsp,40h
	ret

_recv endp
_send proc <:qword,:qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_ipbuffer:qword,_size:qword,_flags:qword
	LOCAL @sizecount:qword
	LOCAL @ipbuffer:qword 
	LOCAL @timecount:qword
	
	mov _hSocket,rcx
	mov _ipbuffer,rdx
	mov _size,r8
	mov _flags,r9
	sub rsp,40h
	mov @timecount,0
	mov rax,_ipbuffer
	mov @ipbuffer,rax
	mov rax,_size
	mov @sizecount,rax
	
	
		.while  <<cmp @sizecount,0>>,GREATER?
		
			invoke send ,_hSocket,@ipbuffer,@sizecount,_flags; 包含flags标志位的结构数据发送服务器  若无错误发生，send()返回所发送数据的总数
			
			.if	<<cmp eax,SOCKET_ERROR>>,zero?
				invoke	WSAGetLastError
				.if <<cmp eax, WSAEWOULDBLOCK>>,zero?
					invoke Sleep,64h ;延时重发
					.if <<cmp @timecount,10>>,greater?
						mov eax,0   
						add rsp,40h
						ret
					.else 
						inc @timecount
					.endif
					
				.else
					mov eax,0
					add rsp,40h
					ret
				.endif
			.elseif <<test eax,eax>>,zero?
				add rsp,40h
				ret
					
			.else
				
				add @ipbuffer,rax
				sub @sizecount,rax
				mov @timecount,0
				
			.endif
		.endw	
		mov eax,1
			
	add rsp,40h		
	ret

_send endp

commpress proc <:qword,:qword,:qword,:qword>  uses rbx rsi rdi gzipbuffer:qword,pgzipbuflength:qword,orgbuffer:qword,orgbuflength:qword
	
	mov gzipbuffer,rcx
	mov pgzipbuflength,rdx
	mov orgbuffer,r8
	mov orgbuflength,r9
	sub rsp,80h
				;invoke RtlZeroMemory,addr z_stream_buffer,sizeof z_stream_buffer
				mov z_stream_buffer.zalloc,0
				mov z_stream_buffer.zfree,0
				mov z_stream_buffer.opaque,0
				
				mov z_stream_buffer.next_in,r8;原数据
				mov z_stream_buffer.avail_in,r9d;原数据长度
				mov z_stream_buffer.next_out,rcx ;压缩后的数据缓冲区
				mov rdx,pgzipbuflength
					mov rdx,[rdx]
				mov z_stream_buffer.avail_out,edx
				;mov z_stream_buffer.avail_out,0;edx
				
				;compression levels :Z_DEFAULT_STRATEGY == 0
				;Z_DEFAULT_COMPRESSION == -1
				FLAGS_GZIP EQU MAX_WBITS +16
				;png文件仅支持 define Z_DEFLATED   8	
				;MAX_WBITS equ 15		png压缩用这个标志
				;第5个参数 zlib_mem_level ==8
				
				invoke deflateInit2_,addr z_stream_buffer,Z_DEFAULT_COMPRESSION,Z_DEFLATED,FLAGS_GZIP,8,Z_DEFAULT_STRATEGY,addr zlib_ver,sizeof z_stream_buffer	;压缩
				
				.if <<cmp eax,Z_OK>>,zero?
				
					
					.while  
						
						
						invoke deflate,addr z_stream_buffer,Z_FINISH
						
						
						.if <<CMP eax,Z_STREAM_END>>,zero?
							.break
						
						.elseif <<CMP eax,Z_OK>>,nozero?	
								mov rcx,0
								mov rdi,pgzipbuflength
								mov [rdi],rcx
								add rsp,80h
								ret
							
						.endif
						
					.endw
					
					invoke deflateEnd,addr z_stream_buffer
					.if <<cmp eax,Z_OK>>,zero?
						
						mov ecx,z_stream_buffer.total_out
						
					.else
						mov rcx,0	
						
					.endif
					
				
				.endif
				
				
				mov rdi,pgzipbuflength
				mov [rdi],rcx
	
	add rsp,80h
	ret

commpress endp

uncommpress proc <:qword,:qword,:qword,:qword>  uses rbx rsi rdi ungzipbuffer:qword,pungzipbuflength:qword,orgbuffer:qword,orgbuflength:qword
	
	
	mov ungzipbuffer,rcx
	mov pungzipbuflength,rdx
	mov orgbuffer,r8
	mov orgbuflength,r9
	
	
	
				sub rsp,80h
				
				
				
				mov z_stream_buffer.zalloc,0
				mov z_stream_buffer.zfree,0
				mov z_stream_buffer.opaque,0
				
				mov z_stream_buffer.next_in,r8;原数据
				mov z_stream_buffer.avail_in,r9d;原数据长度
				mov z_stream_buffer.next_out,rcx ;解压缩后的数据缓冲区
				mov rdx,[rdx]
				mov z_stream_buffer.avail_out,edx
				
					;compression levels :Z_DEFAULT_STRATEGY == 0
					FLAGS_GZIP EQU MAX_WBITS +16
					invoke inflateInit2_,addr z_stream_buffer,FLAGS_GZIP,addr zlib_ver,sizeof z_stream_buffer;解压缩
				
					.if <<cmp eax,Z_OK>>,zero?
				
					
						.while  
						
						
							invoke  inflate ,addr z_stream_buffer,Z_NO_FLUSH;==0
						
						
							.if <<CMP eax,Z_STREAM_END>>,zero?
								.break
							.elseif <<CMP eax,Z_OK>>,nozero?	
								mov rcx,0
								mov rdi,pungzipbuflength
								mov [rdi],rcx
								add rsp,80h
								ret
							.endif
							
							
							
						
						.endw
					
						invoke inflateEnd,addr z_stream_buffer
						.if <<cmp eax,Z_OK>>,zero?
						
							mov ecx,z_stream_buffer.total_out
						
						.else
							mov rcx,0
						
						.endif
					
				
					.endif
				
				
				
				mov rdi,pungzipbuflength
				mov [rdi],rcx
				
				
				
				
				
				
				
	
	add rsp,80h
	
	
	ret

uncommpress endp

uncommpress_png proc <:qword,:qword,:qword,:qword>  uses rbx rsi rdi ungzipbuffer:qword,pungzipbuflength:qword,orgbuffer:qword,orgbuflength:qword
	
	
	mov ungzipbuffer,rcx
	mov pungzipbuflength,rdx
	mov orgbuffer,r8
	mov orgbuflength,r9
	
	
	
				sub rsp,80h
				
				
				
				mov z_stream_buffer.zalloc,0
				mov z_stream_buffer.zfree,0
				mov z_stream_buffer.opaque,0
				
				mov z_stream_buffer.next_in,r8;原数据
				mov z_stream_buffer.avail_in,r9d;原数据长度
				mov z_stream_buffer.next_out,rcx ;解压缩后的数据缓冲区
				
				.if <<test rdx,rdx>>,zero?
					
					mov z_stream_buffer.avail_out,0
				.else
					mov rdx,[rdx]	
					mov z_stream_buffer.avail_out,edx
				.endif
				
				
				
					;compression levels :Z_DEFAULT_STRATEGY == 0
					FLAGS_GZIP EQU MAX_WBITS +16
					invoke inflateInit2_,addr z_stream_buffer,MAX_WBITS,addr zlib_ver,sizeof z_stream_buffer;解压缩
				
					.if <<cmp eax,Z_OK>>,zero?
				
					
						.while  
						
						
							invoke  inflate ,addr z_stream_buffer,Z_NO_FLUSH;==0
						
						
							.if <<CMP eax,Z_STREAM_END>>,zero?
								.break
							.elseif <<CMP eax,Z_OK>>,nozero?	
								mov rcx,0
								mov rdi,pungzipbuflength
								mov [rdi],rcx
								add rsp,80h
								ret
							.endif
							
							
							
						
						.endw
					
						invoke inflateEnd,addr z_stream_buffer
						.if <<cmp eax,Z_OK>>,zero?
						
							mov ecx,z_stream_buffer.total_out
						
						.else
							mov rcx,0
						
						.endif
					
				
					.endif
				
				
				
				mov rdi,pungzipbuflength
				mov [rdi],rcx
				
				
				
				
				
				
				
	
	add rsp,80h
	
	
	ret

uncommpress_png endp


EncryptMessage_and_send proc <:qword,:qword,:qword,:qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_pCtxtHandle:qword,_json_buffer:qword,_json_buffer_length:qword,_pjson_send_buffer:qword,_pjson_send_buffer_length:qword
		LOCAL @hSocket:qword
		LOCAL @json_buffer_for_https_count:qword
		LOCAL @json_buffer:qword
		LOCAL @thistimelength:qword;本次参与运算的长度
		LOCAL @hheap:qword
		LOCAL @SecPkgContext_StreamSizes_buffer :SecPkgContext_StreamSizes
		
		LOCAL @temp_buffer_for_list			[5]:_SecBuffer; 5 dup (<?>
		LOCAL @EncryptMessage_SecBufferDesc_buffer			:_SecBufferDesc
		mov @hSocket,rcx
		mov _hSocket,rcx
		mov _pCtxtHandle,rdx
		
		mov _json_buffer,r8
		mov @json_buffer,r8
		mov _json_buffer_length,r9
		mov  @json_buffer_for_https_count,r9
		
		sub rsp,80h
	
		invoke GetProcessHeap
			mov @hheap,rax	
			
		.while <<cmp @json_buffer_for_https_count,0>>,greater?
			invoke RtlZeroMemory,_pjson_send_buffer,_pjson_send_buffer_length
			invoke QueryContextAttributesA,_pCtxtHandle,SECPKG_ATTR_STREAM_SIZES,addr @SecPkgContext_StreamSizes_buffer
			.if <<cmp rax,0>>,nozero?
				
				jmp exit
			.endif
			mov rcx,@json_buffer_for_https_count
			mov ebx,@SecPkgContext_StreamSizes_buffer.cbMaximumMessage	
			.if <<cmp rcx,rbx>>,GREATER?
				mov @thistimelength,rbx
				sub @json_buffer_for_https_count,rbx
			.else
				mov @thistimelength,rcx
				mov @json_buffer_for_https_count,0
			.endif			
		
			mov @EncryptMessage_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
			mov @EncryptMessage_SecBufferDesc_buffer.cBuffers,4
			lea rax,@temp_buffer_for_list
			mov @EncryptMessage_SecBufferDesc_buffer.pBuffers,rax
			
			mov ecx,@SecPkgContext_StreamSizes_buffer.cbHeader
			mov [rax+_SecBuffer.cbBuffer],ecx
			
			mov [rax+_SecBuffer.BufferType],SECBUFFER_STREAM_HEADER ;==7
			
			mov rsi,_pjson_send_buffer
			mov [rax+_SecBuffer.pvBuffer],rsi
			
			add rsi,rcx
			
			add rax,sizeof _SecBuffer
			
			mov rcx,@thistimelength
			mov [rax+_SecBuffer.cbBuffer],ecx
			mov [rax+_SecBuffer.BufferType],SECBUFFER_DATA ;==1
			
			mov [rax+_SecBuffer.pvBuffer],rsi
			
			
			mov rdi,rsi
			mov rsi,@json_buffer
			
			mov rcx,@thistimelength
			cld
			rep movsb
			
			
			mov rsi,rdi
			
			
			
			
			add rax,sizeof _SecBuffer
			mov ecx,@SecPkgContext_StreamSizes_buffer.cbTrailer
			mov [rax+_SecBuffer.cbBuffer],ecx
			mov [rax+_SecBuffer.BufferType],SECBUFFER_STREAM_TRAILER ;==6
			
			mov [rax+_SecBuffer.pvBuffer],rsi
			
			
			
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			
			
			mov ecx,@SecPkgContext_StreamSizes_buffer.cbHeader
			
			mov @EncryptMessage_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
			mov @EncryptMessage_SecBufferDesc_buffer.cBuffers,4
			
			lea rax,@temp_buffer_for_list
			mov @EncryptMessage_SecBufferDesc_buffer.pBuffers,rax
			
			invoke EncryptMessage,_pCtxtHandle,0,addr @EncryptMessage_SecBufferDesc_buffer,0
			
			.if <<test rax,rax>>,nozero?
				
				jmp exit
			.endif
			
			lea rax,@temp_buffer_for_list
			
			mov ecx,@SecPkgContext_StreamSizes_buffer.cbHeader
			mov edx,[rax+_SecBuffer.cbBuffer]
			.if <<cmp ecx,edx>>,nozero?
				;也就是说加密的数据大小发生了变化，需要调整一下每个类型的位置
				nop
				mov rdi,[rax+_SecBuffer.pvBuffer]
				add rdi,rdx
				add rax,sizeof _SecBuffer;第一个尾部
				mov rsi,[rax+_SecBuffer.pvBuffer];第二个
				mov ecx,[rax+_SecBuffer.cbBuffer]
				cld
				rep movsb
				
				add rax,sizeof _SecBuffer
				mov rsi,[rax+_SecBuffer.pvBuffer];第三个
				mov ecx,[rax+_SecBuffer.cbBuffer]
				cld
				rep movsb
			.endif
			
			lea rax,@temp_buffer_for_list
			mov ecx,[rax+_SecBuffer.cbBuffer]
			add rax,sizeof _SecBuffer
			add ecx,[rax+_SecBuffer.cbBuffer]
			add rax,sizeof _SecBuffer
			add ecx,[rax+_SecBuffer.cbBuffer]
			mov rax,rcx
			
			invoke _send,@hSocket, _pjson_send_buffer,rax,0
		
			.if <<test eax,eax>>,zero?
				
				jmp exit
				
			.endif
			
			mov rcx,@thistimelength
			add @json_buffer,rcx
			
		.endw	
exit:		
	add rsp,80h	
	ret		;返回0 是发送错误，1是正确，其余值是EncryptMessage 错误

EncryptMessage_and_send endp
asciitoint proc  <:qword,:qword>  uses rbx rsi rdi r10 r11 _pbuffer:qword,_buffer_length:qword
	LOCAL @data_size:qword
				mov _pbuffer,rcx
				mov _buffer_length,rdx
				mov r8,rdx
				and @data_size,0
				mov rbx,0
				mov rdi,_pbuffer
				and @data_size,0
				.while <<test r8,r8>>,nozero?
												
					
					mov rax,0
					mov al,[rdi+rbx]
					.if <<cmp al,"f">>,ABOVE?
						
						.break
					.endif	
												
					.if <<cmp al,"0">>,BELOW?
						
						.break
					.endif	
					.if <<cmp al,"a">>,ABOVE?||EQUAL?
												
						.if <<cmp al,"f">>,BELOW?||EQUAL?
							SUB AL,20H
							sub al,30h
							SUB AL,7
						.else
							
							.break	
						.endif
												
					.elseif <<cmp al,"A">>,ABOVE?||EQUAL?
												
						.if <<cmp al,"F">>,BELOW?||EQUAL?
							sub al,30h
							SUB AL,7
						.else
								
							.break	
						.endif
												
					.elseif <<cmp al,"0">>,ABOVE?||EQUAL?
												
						.if <<cmp al,"9">>,BELOW?||EQUAL?
														
							sub al,"0"
														
						.else
								
							.break
						.endif
					.else
						
						.break
					.endif
					mov rcx,0
					mov r9,0
					mov r9b,al
					mov rax,@data_size
					mov rcx,10
					mul rcx
					mov @data_size,rax
					
					
					
					add @data_size,r9
												
					inc rbx
					dec r8
				.endw
				mov 	rax,@data_size						
	
	
	
	ret

asciitoint endp


wait_and_recv_data_for_http proc  <:qword,:qword,:qword,:qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_precv_buffer:qword,_precv_buffer_length:qword,_pdecrypt_buffer:qword,_pdecrypt_buffer_length:qword,_returnbody_lehgth:qword			;_;https解密后的缓冲区，原则上讲包含压缩数据
										;_precv_buffer:body 数据 （如果压缩的话，那么是解压缩数据）_pdecrypt_buffer：原始html数据
	LOCAL @readcount:qword		;每次接收到的数据
	LOCAL @retry_count:qword	;接收等待次数
	LOCAL @hSocket:qword
	LOCAL @temp_ip_buffer:qword
	LOCAL @chunked_offset_in_all_recv:qword
	LOCAL @uncompress_count:qword
	LOCAL @compress_count:qword
	LOCAL @deccount		:qword	;解密计数
	
	LOCAL  @flags_gzip:qword
	LOCAL @flags_deflate:qword
	LOCAL @flags_chunked:qword	;表示的长度
	LOCAL @data_size:qword		;content-length 表示的长度
	LOCAL @chunked_end_size:qword
	LOCAL @chunked_offset_lehgth:qword	;需要合并的移动数据的长度
	LOCAL @pdecrypt_buffer:qword
	LOCAL @pdecrypt_buffer_length:qword
	
	LOCAL @content_length_offset_lehgth:qword
	LOCAL @instrbuffer	[8]:qword
	LOCAL @tempbuffer	[80h]:qword
	LOCAL @return_count:qword
	LOCAL @temp_buffer_for_list			[5]:_SecBuffer
	
	
	LOCAL @EncryptMessage_SecBufferDesc_buffer	:_SecBufferDesc
	LOCAL  @heap_mid_buffer:qword
	LOCAL @flags:qword
	
			mov _hSocket,rcx
			
			mov _precv_buffer,rdx
			mov _precv_buffer_length,r8
			
			mov _pdecrypt_buffer,r9
	
			mov @pdecrypt_buffer,r9
			mov rax,_pdecrypt_buffer_length
			mov @pdecrypt_buffer_length,rax
	
	
			mov @hSocket,rcx
			sub rsp,80h
		;	invoke RtlZeroMemory,addr EncryptMessage_recv_buffer, sizeof EncryptMessage_recv_buffer
			and @chunked_offset_lehgth,0
			and @data_size,0
			and @flags_chunked,0
			and @deccount,0
			and @data_size,0	
			and @flags_gzip,0
			and @flags_deflate,0
			;lea rdi,EncryptMessage_recv_buffer
			mov rdi,_pdecrypt_buffer
			mov @temp_ip_buffer,rdi
			and @readcount,0	
			and @retry_count,0	
			and @chunked_offset_in_all_recv,0
			and @flags,0
			
			invoke GetProcessHeap
			mov rcx,_precv_buffer_length
			shl rcx,1
			invoke HeapAlloc,rax,HEAP_ZERO_MEMORY,rcx
			.if <<test rax,rax>>,zero?
				
				mov rax,0
				jmp @exit
			.endif
			mov @heap_mid_buffer,rax
			
		@again_:
		.while ;第一次接收，给服务端3秒的等待时间
			and @readcount,0
			invoke ioctlsocket,@hSocket,FIONREAD,addr @readcount ;阻塞模式 在一次recv()中所接收的所有数据量。
                        ; 这通常与套接口中排队的数据总量相同。
                        ; 如果S是SOCK_DGRAM 型，则FIONREAD
                        ; 返回套接口上排队的第一个数据报大小。	
                        
                        ;正常返回0
                        
           		.if <<test eax,eax>>,zero?		
                	
                       		 .if <<cmp @readcount,0>>,zero?	;客户端connect 之后 如果没有发送数据 就会 @readcount== 0 
				
					
					invoke Sleep,100
				
					inc @retry_count
				
				
					.if  <<cmp @retry_count ,10>>,less?	;给服务端3秒的等待时间;如果三次都读不到数据，说明数据已经读完了，或者服务端已经关闭了
						
						mov rcx,@retry_count
						lea rsi,@instrbuffer
						
						mov [rsi],rcx
						
						invoke wvsprintfA,addr @tempbuffer,addr atext(network_retry_time,"ioctlsocket非HTTPS 调用第%d次",0dh,0ah),rsi
						invoke lstrlenA,addr @tempbuffer
						mov r8,rax
						invoke logout,addr @tempbuffer,r8
						
						
						jmp @again_
						
					.else
						.break	
					.endif
				
				.else
					
					
					mov rcx,@temp_ip_buffer
					;lea rdi,EncryptMessage_recv_buffer
					mov rdi,_pdecrypt_buffer
					sub rcx,rdi	;缓冲区已经占用的空间
					
					.if <<cmp rcx,_pdecrypt_buffer_length>>,noless?
						mov rcx,0
						mov @temp_ip_buffer,rdi	;如果缓冲区用完了，那就重新从头开始
					.endif
					
					mov rax,_pdecrypt_buffer_length
					sub rax,rcx;剩余可用的空间
					
					.if <<cmp @readcount,rax>>,greater?	;单次接收的数据不能超过缓冲区剩余空间容量
						mov @readcount,rax
					.endif
					mov rdi,@temp_ip_buffer
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					invoke _recv,@hSocket,rdi,@readcount,0	;
					
					
					.if <<cmp rax,0>>,zero?
						mov rax,0
						jmp @exit	
					.endif
					
				
					mov rcx,@readcount
					
					add  @temp_ip_buffer,rcx
				
					
					
					
					
					mov rcx,@readcount
					lea rsi,@instrbuffer
					mov rax,0
					
						
					mov [rsi],rcx
					
					
					mov rcx,@temp_ip_buffer
				;	lea rdi,EncryptMessage_recv_buffer
					mov rdi,_pdecrypt_buffer
					
					sub rcx,rdi	;缓冲区已经占用的空间
					mov [rsi+8h],rcx
					invoke wvsprintfA,addr @tempbuffer,addr atext(network_recv,"非HTTPS recv 成功recv %d	字节总共接收 %d	字节",0dh,0ah),rsi
					invoke lstrlenA,addr @tempbuffer
					mov r8,rax
					invoke logout,addr @tempbuffer,r8
				;	invoke WriteFile,hfile_error_log,addr @tempbuffer,r8,addr  @return_count,0
					
					and @readcount,0	
					and @retry_count,0	
					
					
				.endif
			.else
				mov rax,0
				
				jmp @exit	
			.endif
			
				
		.endw
		
				
			
					mov rcx,@temp_ip_buffer
				
					mov rdi,_pdecrypt_buffer
					sub rcx,rdi	;缓冲区已经占用的空间
					mov 	@deccount,rcx		
					mov r8,@deccount
					sub r8,sizeof Content_Length-1
					mov @content_length_offset_lehgth,0
					mov @data_size,0
					mov rbx,0
					
					.while <<test r8,r8>>,GREATER?	;是Content_Length 类型的长度吗？
						mov rdi,@pdecrypt_buffer
						lea rsi,Content_Length		;检测数据长度
					
						lea rdi,[rdi+rbx]
						mov rcx,sizeof Content_Length-1
						cld
						repz cmpsb
						.if zero?		
							
							
							push rdi
							push rdx
							mov byte ptr [rdi-1],0
						
							pop rdx
							pop rdi
							
							
							
							
							mov rsi,@pdecrypt_buffer
							mov rax,rdi
							
							sub rax,rsi
							mov r10,@deccount
							sub r10,rax	;剩余可读的有效内存
							sub r10,4	;0a0d0a0d长度
							
							mov rbx,0
							
						@@:	
							.while <<test r10,r10>>,greater?	;剩余可读的有效内存里有没有完整的数据长度
								
								.if << cmp dword ptr [rdi+rbx],0a0d0a0dh>>,zero?;Content_Length类型的长度后面紧跟两个回车换行 0D0A 0D0A
									
										
											;有完整的数据长度
											
									mov r8,rbx
											
									invoke asciitoint,rdi,r8
									mov @content_length_offset_lehgth,rax
									add @data_size,rax
									
									lea rdi,[rdi+rbx+4];+4 == 0a0d0a0d
									
									push rdi
									
									mov rsi,rdi
									
									mov rdi,@heap_mid_buffer
									mov rcx,@content_length_offset_lehgth
									cld
									rep movsb
									
									.if <<cmp word ptr  [rsi],0a0dh>>,nozero?;每个块都是0D0A结束;也有特殊情况，百度语音识别很不正规
												
											;	
									.endif
									
									
									pop rdi
									
									inc rdi
									inc rdi		;0d0a
									
									mov rbx,0
									sub r10,@content_length_offset_lehgth
									sub r10,4
									sub r10,2;个块都是0D0A结束		
									jmp @b
									
								.endif
								inc rbx
								dec r10
								
							.endw
							.break
							
						
						.endif
						
						inc rbx
						dec r8
					
					.endw
					
					
					and @flags_chunked,0
				
					mov r8,@deccount
					sub r8,Transfer_Encoding_size
				
					mov rdx,0
					.while <<test r8,r8>>,GREATER?		;是块状起始类型的长度吗？
						mov rdi,@pdecrypt_buffer
						lea rsi,Transfer_Encoding		;检测数据长度
					
						lea rdi,[rdi+rdx]
						mov rcx,Transfer_Encoding_size	;"Transfer-Encoding: chunked od oa od oa "格式的长度
						cld
						repz cmpsb
						.if zero?		;找到块状起始标志 
									
							push rdi
							push rdx
							mov byte ptr [rdi-1],0
							
							pop rdx
							pop rdi
							mov rcx,@deccount	;剩余可读的有效内存 总共解密的有效数据
							mov rbx,0
							
							
						@@:	
							.while <<cmp rcx,0>>,greater?	;剩余可读的有效内存里有没有完整的数据长度 把检测到的数据拷贝到 @heap_mid_buffer
								and @flags_chunked,0
								
							;	.if << cmp byte ptr [rdi+rbx],"0">>,zero?;块结束标志，后面的不需要了 如果是"b00"呢？参考 rerror.bmp
														
							;		.break
							;	.endif
								
								.if << cmp byte ptr [rdi+rbx],0dh>>,zero?
									
									.if << cmp ecx,1>>,above?
									
										.if << cmp byte ptr [rdi+rbx+1],0ah>>,zero?;Transfer-Encoding: chunked od oa od oa 之后是数据的长度是16进制ASCII表示的，长度之后是ODOA结束
											;有完整的数据长度
											
											
											mov @chunked_offset_in_all_recv,rdi
											
											add @chunked_offset_in_all_recv,rbx
											inc @chunked_offset_in_all_recv	;跳过0D0A
											inc @chunked_offset_in_all_recv
											
											mov rsi,@pdecrypt_buffer
											sub @chunked_offset_in_all_recv,rsi
											
											
											mov r9,rbx
											
											mov rbx,0
											
											mov rax,0
											.while <<test r9,r9>>,GREATER?	;计算@flags_chunked;块大小
												
												shl @flags_chunked,4 ;块状用16进制ASCII表示
												
												mov al,[rdi+rbx]
												.if <<cmp al,"f">>,ABOVE?
													
													.break
												.endif	
												
												.if <<cmp al,"0">>,BELOW?
													
													.break
												.endif	
												.if <<cmp al,"a">>,ABOVE?||EQUAL?
												
													.if <<cmp al,"f">>,BELOW?||EQUAL?
														SUB AL,20H
														sub al,30h
														SUB AL,7
													.else
														
														.break	
													.endif
												
												.elseif <<cmp al,"A">>,ABOVE?||EQUAL?
												
													.if <<cmp al,"F">>,BELOW?||EQUAL?
														sub al,30h
														SUB AL,7
													.else
														
														.break	
													.endif
												
												.elseif <<cmp al,"0">>,ABOVE?||EQUAL?
												
													.if <<cmp al,"9">>,BELOW?||EQUAL?
														
														sub al,"0"
														
													.else
														
														.break
													.endif
												.else
													
													.break
												.endif
												or @flags_chunked,rax
												
												inc rbx
												dec r9
											.endw
											
											mov rdi,@heap_mid_buffer
											add rdi,@chunked_offset_lehgth;第一次计算时为0
											mov rcx,@flags_chunked;本块大小
											
											add @chunked_offset_lehgth,rcx
											mov rsi,@pdecrypt_buffer
											add rsi,@chunked_offset_in_all_recv
											
											
											cld
											rep movsb
											
											;;;;继续检测，或许有很多块
											
											.if <<cmp word ptr  [rsi],0a0dh>>,nozero?;每个块都是0D0A结束
												;invoke MessageBox,
												;int 3
											.endif
											
											
											inc @chunked_offset_in_all_recv	;跳过0D0A
											inc @chunked_offset_in_all_recv	;每个块都是0D0A结束
											mov rcx,@flags_chunked;本块大小
											add @chunked_offset_in_all_recv,rcx
											
											mov rdi,@pdecrypt_buffer
											add rdi,@chunked_offset_in_all_recv
											
											
											
															
											mov rbx,0
											mov rcx,@deccount
											sub rcx,@chunked_offset_in_all_recv
											sub rcx,2;;每个块都是0D0A结束
											jmp @b
											
											
										.else
											and @data_size,0
											.break		
										.endif
										
										
										
									.else
										and @data_size,0
										.break	
										
									.endif
									
									
									
									
								.endif
								inc rbx
								
								dec rcx
								
							.endw
							.break
							
							
							
						.else	
							inc rdx
					
						.endif
						dec r8
					
					.endw
					
					mov rax,@chunked_offset_lehgth
					.if <<cmp rax,0>>,nozero?
						mov @data_size,rax
					.endif
					
					
					
			
				
				
				mov r8,@deccount	;解密计数
				sub r8,sizeof Content_Encoding-1
				
				
				and @flags_deflate,0
				and @flags_gzip,0
				mov rbx,0
				.while <<test r8,r8>>,GREATER?;检测网页内容采用哪种压缩
					mov rdi,@pdecrypt_buffer
					lea rsi,Content_Encoding		
					
					lea rdi,[rdi+rbx]
					mov rcx,sizeof Content_Encoding-1
					cld
					repz cmpsb
					.if zero?		
						
						push rdi
						lea rsi,gzip_compress
						mov rcx,sizeof gzip_compress-1
						cld
						repz cmpsb	;是gzip压缩吗？
						.if zero?
							pop rdi
							or @flags_gzip,1
							and @flags_deflate,0
						.else
							pop rdi
							lea rsi,deflate__compress
							mov rcx,sizeof deflate__compress-1
							cld
							repz cmpsb
							.if zero?
								and @flags_gzip,0
								or @flags_deflate,1
								
							.endif
						
						.endif
						
						.break
					.else	
						inc rbx
					
					.endif
					dec r8
					
				.endw
				
				
				
				
				mov rcx,@data_size
				.if <<cmp @data_size,0>>,ABOVE?
				
					;已经接收完了，其余的不需要了
					nop
					mov rcx,@data_size
					mov rbx,@uncompress_count
					mov rsi,_precv_buffer
					mov rdi,@heap_mid_buffer
					mov rax,_precv_buffer_length
					mov @uncompress_count,rax
					
					
					;mov rax,@flags_deflate
					;mov rcx,@flags_gzip
					.if <<cmp @flags_deflate,1>>,zero?
						invoke uncompress,_precv_buffer,addr @uncompress_count,rdi,@data_size		;这个是ZLIB内部的
					.elseif  <<cmp @flags_gzip,1>>,zero?
						invoke uncommpress,_precv_buffer,addr @uncompress_count,rdi,@data_size
					.else
						mov rsi,@heap_mid_buffer	
						mov rcx,@data_size
						mov rdi,_precv_buffer
						cld
						rep movsb
						mov rax,0
					.endif
					mov @flags,1
					
					.if <<test rax,rax>>,zero?
						
						;解压成功
						nop
						mov r8, @uncompress_count
						sub r8,sizeof access_token_token-1	
						
					;	invoke SetDlgItemTextA,hWnd_main,1004,_precv_buffer
						
						
						
						
						.while			;如果还有剩余的数据，那就继续接收
							@@@again_:
							and @readcount,0
							invoke ioctlsocket,@hSocket,FIONREAD,addr @readcount ;阻塞模式 在一次recv()中所接收的所有数据量。
                     					   ; 这通常与套接口中排队的数据总量相同。
                     					   ; 如果S是SOCK_DGRAM 型，则FIONREAD
                     					   ; 返回套接口上排队的第一个数据报大小。	
                        
                     						   ;正常返回0
                        
           						.if <<test eax,eax>>,zero?		
                	
                       						 .if <<cmp @readcount,0>>,zero?	;客户端connect 之后 如果没有发送数据 就会 @readcount== 0 
				
					
									invoke Sleep,100
				
									inc @retry_count
				
									.if  <<cmp @retry_count ,3>>,less?||equal?	;
										mov rcx,@retry_count
										lea rsi,@instrbuffer
						
										mov [rsi],rcx
						
										invoke wvsprintfA,addr @tempbuffer,addr atext(network_tail_time,"ioctlsocket 已经成功尾部清理调用第%d次",0dh,0ah),rsi
										invoke lstrlenA,addr @tempbuffer
										mov r8,rax
										invoke logout,addr @tempbuffer,r8
									;	invoke WriteFile,hfile_error_log,addr @tempbuffer,r8,addr  @return_count,0
										jmp @@@again_
									
						
									.endif
				
								.else
									mov rdi,@pdecrypt_buffer
									mov rax,@readcount
					
									invoke _recv,@hSocket,rdi,@readcount,0
									
									
									
									
									jmp @@@again_
					
								
					
								.endif
								
								.break
								
							.else
									
							.endif
							.break
						.endw
						
						
						
						
						
						mov rax,_returnbody_lehgth
						mov rcx,@data_size
						mov [rax],rcx
						mov rax,1;接收成功
						
					.else
						mov rax,0
						
					
					.endif
				
				
				
				.else
					mov rax,0
					
				.endif
				
					
			
			
	
	@exit:
	
	invoke GetProcessHeap
	invoke HeapFree,rax,0,@heap_mid_buffer
	mov rax,@flags
	add rsp,80h
	
	;lea rax,precv_buffer
	
	ret

wait_and_recv_data_for_http endp

wait_and_recv_data_for_https proc  <:qword,:qword,:qword,:qword,:qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_pCtxtHandle:qword,_precv_buffer:qword,_precv_buffer_length:qword,_pdecrypt_buffer:qword,_pdecrypt_buffer_tength:qword,_returnbody_lehgth:qword			;_;https解密后的缓冲区，原则上讲包含压缩数据
										;_precv_buffer:body 数据 （如果压缩的话，那么是解压缩数据）_pdecrypt_buffer：原始html数据
	LOCAL @readcount:qword		;每次接收到的数据
	LOCAL @retry_count:qword	;接收等待次数
	LOCAL @hSocket:qword
	LOCAL @temp_ip_buffer:qword
	LOCAL @chunked_offset_in_all_recv:qword
	LOCAL @uncompress_count:qword
	LOCAL @compress_count:qword
	LOCAL @deccount		:qword	;解密计数
	LOCAL @flags_gzip:qword
	LOCAL @flags_deflate:qword
	LOCAL @flags_chunked:qword	;表示的长度
	LOCAL @data_size:qword		;content-length 表示的长度
	LOCAL @chunked_end_size:qword
	LOCAL @chunked_offset_lehgth:qword	;需要合并的移动数据的长度
	LOCAL @pdecrypt_buffer:qword
	LOCAL @pdecrypt_buffer_length:qword
	LOCAL @content_length_offset_lehgth:qword
	LOCAL @instrbuffer	[8]:qword
	LOCAL @tempbuffer	[80h]:qword
	LOCAL @return_count:qword
	LOCAL @temp_buffer_for_list			[5]:_SecBuffer
	LOCAL @EncryptMessage_SecBufferDesc_buffer			:_SecBufferDesc
	LOCAL  @heap_mid_buffer:qword
	LOCAL @flags:qword
		mov _hSocket,rcx
		mov _pCtxtHandle,rdx
		mov _precv_buffer,r8
		mov _precv_buffer_length,r9	;equ 1280*720*4 ;png
			
		mov r9,_pdecrypt_buffer
	
		mov @pdecrypt_buffer,r9		;已经解密的数据
		mov rax,_pdecrypt_buffer_tength	;equ 1280*720*4 ;png
		mov @pdecrypt_buffer_length,rax
	
		mov @hSocket,rcx
		sub rsp,80h
		;	invoke RtlZeroMemory,addr EncryptMessage_recv_buffer, sizeof EncryptMessage_recv_buffer
		and @chunked_offset_lehgth,0
		and @data_size,0
		and @flags_chunked,0
		and @deccount,0
		and @data_size,0	
		and @flags_gzip,0
		and @flags_deflate,0
			;lea rdi,EncryptMessage_recv_buffer
		mov rdi,_precv_buffer
		mov @temp_ip_buffer,rdi
		and @readcount,0	
		and @retry_count,0	
		and @chunked_offset_in_all_recv,0
		and @flags,0
			
		invoke GetProcessHeap
		mov rcx,_precv_buffer_length
		shl rcx,1
		invoke HeapAlloc,rax,HEAP_ZERO_MEMORY,rcx
		.if <<test rax,rax>>,zero?
			mov rax,0
			add rsp,80h
			ret
		.endif
		mov @heap_mid_buffer,rax
			
		@again_:
		.while <<cmp rax,rax>>,zero?
			and @readcount,0
			invoke ioctlsocket,@hSocket,FIONREAD,addr @readcount ;阻塞模式 在一次recv()中所接收的所有数据量。  ; 这通常与套接口中排队的数据总量相同。  ; 如果S是SOCK_DGRAM 型，则FIONREAD
                      
                        ; 返回套接口上排队的第一个数据报大小。	    ;正常返回0
           	.if <<test eax,eax>>,zero?		
                .if <<cmp @readcount,0>>,zero?	;客户端connect 之后 如果没有发送数据 就会 @readcount== 0 
					invoke Sleep,100
					inc @retry_count
					.if  <<cmp @retry_count ,10>>,less?	;给服务端2秒的等待时间;如果20次都读不到数据，说明数据已经读完了，或者服务端已经关闭了
						jmp @again_
					.else
						mov rcx,@retry_count
						lea rsi,@instrbuffer
						mov [rsi],rcx
					;	invoke wvsprintfA,addr @tempbuffer,addr atext(network_retry_time_https,"ioctlsocket 调用第%d次",0dh,0ah),rsi
					;	invoke lstrlenA,addr @tempbuffer
					;	mov r8,rax
					;	invoke logout,addr @tempbuffer,r8
						invoke logout,addr atext(network_retry_time_https,"wait_and_recv_data_for_https 10次内没有接收到数据--那就退出吧",0dh,0ah),sizeof network_retry_time_https
						mov rax,0
						.break
					.endif
				.else
					mov rcx,@temp_ip_buffer ;动态变化的_precv_buffer指针 ;运行中充当recv 缓冲
					mov rdi,_precv_buffer
					sub rcx,rdi	;缓冲区已经占用的空间
					
					.if <<cmp rcx,_precv_buffer_length>>,noless?
						mov rcx,0
						mov @temp_ip_buffer,rdi
					.endif
					
					mov rax,_precv_buffer_length	;equ 1280*720*4
					sub rax,rcx;剩余可用的空间
					
					.if <<cmp @readcount,rax>>,greater?	;单次接收的数据不能超过缓冲区剩余空间容量
						mov @readcount,rax
					.endif
					mov rdi,@temp_ip_buffer
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					
					invoke _recv,@hSocket,rdi,@readcount,1	;
					
					.if <<cmp rax,0>>,zero?
						mov rax,0
						jmp @exit	
					.endif
					mov rcx,@readcount
					add  @temp_ip_buffer,rcx;调整缓冲区指针
				
					mov rcx,@readcount
					lea rsi,@instrbuffer
					mov rax,0
					mov [rsi],rcx
					mov rcx,@temp_ip_buffer
					mov rdi,_precv_buffer
					sub rcx,rdi	;缓冲区已经占用的空间
					mov [rsi+8h],rcx
					invoke wvsprintfA,addr @tempbuffer,addr atext(network_recv_https,"recv 成功recv %d	字节总共接收 %d	字节",0dh,0ah),rsi
					invoke lstrlenA,addr @tempbuffer
					mov r8,rax
					invoke logout,addr @tempbuffer,r8
					and @readcount,0	
					and @retry_count,0	
				.endif
			_againdec:
				.while <<cmp rax,rax>>,zero?
					mov @EncryptMessage_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
					mov @EncryptMessage_SecBufferDesc_buffer.cBuffers,4
					lea rax,@temp_buffer_for_list
					mov @EncryptMessage_SecBufferDesc_buffer.pBuffers,rax
					
					mov rcx,@temp_ip_buffer
					mov rdi,_precv_buffer
					sub rcx,rdi;缓冲区已经占用的空间
			
					mov [rax+_SecBuffer.cbBuffer],ecx
					mov [rax+_SecBuffer.BufferType],SECBUFFER_DATA ;==1
			
					mov rsi,_precv_buffer
					mov [rax+_SecBuffer.pvBuffer],rsi
			
					add rsi,rcx
					add rax,sizeof _SecBuffer
			
					mov [rax+_SecBuffer.cbBuffer],0
					mov [rax+_SecBuffer.BufferType],0
					mov [rax+_SecBuffer.pvBuffer],0
					add rsi,rcx
					add rax,sizeof _SecBuffer
					
					mov [rax+_SecBuffer.cbBuffer],0
					mov [rax+_SecBuffer.BufferType],0
					mov [rax+_SecBuffer.pvBuffer],0
					add rax,sizeof _SecBuffer
					
					mov [rax+_SecBuffer.cbBuffer],0
					mov [rax+_SecBuffer.BufferType],0
					mov [rax+_SecBuffer.pvBuffer],0
			
					invoke DecryptMessage,_pCtxtHandle,addr @EncryptMessage_SecBufferDesc_buffer,0,0
					.if <<cmp eax,SEC_I_CONTEXT_EXPIRED>>,zero? ;发送方已经关闭了，可能已经发送完成了The message sender has finished using the connection and has initiated a shutdown.
				
						lea rax,@temp_buffer_for_list
						invoke logout,addr atext (_error_send_finished_server,"发送方已经关闭了，可能已经发送完成了（The message sender has finished using the connection and has initiated a shutdown）"),sizeof _error_send_finished_server
						jmp process_data
					.elseif <<cmp eax,SEC_E_OUT_OF_SEQUENCE>>,zero? ;该消息没有按正确的顺序接收。
				
						lea rax,@temp_buffer_for_list
						invoke logout,addr atext (_error_send_OUT_OF_SEQUENC_server,"该消息没有按正确的顺序接收"),sizeof _error_send_OUT_OF_SEQUENC_server
						nop
						jmp @exit
					.elseif <<cmp eax,SEC_E_INVALID_HANDLE>>,zero? ;在phContext参数中指定了一个无效的上下文句柄
						invoke logout,addr atext (_error_send_INVALID_HANDLE_server,"在phContext参数中指定了一个无效的上下文句柄"),sizeof _error_send_INVALID_HANDLE_server
						jmp @exit
					.elseif <<cmp eax,SEC_E_INVALID_TOKEN>>,zero? ;缓冲区类型错误或没有找到类型为SECBUFFER_DATA的缓冲区
						invoke logout,addr atext (_error_send_INVALID_TOKEN_server,"缓冲区类型错误或没有找到类型为SECBUFFER_DATA的缓冲区"),sizeof _error_send_INVALID_TOKEN_server
						jmp @exit
				
					.elseif <<cmp eax,SEC_E_MESSAGE_ALTERED>>,zero? 	;消息已被更改	
						invoke logout,addr atext (_error_send_MESSAGE_ALTERED_server,"消息已被更改"),sizeof _error_send_MESSAGE_ALTERED_server
						jmp @exit
					.elseif <<cmp eax ,SEC_E_OK>>,zero?	;正常完成没有关闭
				
						lea rax,@temp_buffer_for_list
						mov rdi,@pdecrypt_buffer
				
						mov r8,4
						add rdi,@deccount
						.while <<test r8,r8>>,GREATER?		;解密的数据保存到@pdecrypt_buffer
					
							.if <<cmp [rax+_SecBuffer.BufferType],SECBUFFER_DATA>>,zero?
						
								mov ecx,[rax+_SecBuffer.cbBuffer]
								mov rsi,[rax+_SecBuffer.pvBuffer]
						
								add @deccount,rcx
								cld
								rep movsb
						
							.endif
							add rax,sizeof _SecBuffer
							dec r8
						.endw
						
						
						lea rax,@temp_buffer_for_list
						mov rdi,@pdecrypt_buffer
				
						mov r8,4
						add rdi,@deccount
						.while <<test r8,r8>>,GREATER?		;解密的数据保存到@pdecrypt_buffer
					
							.if <<cmp [rax+_SecBuffer.BufferType],SECBUFFER_ALERT>>,zero?
							
								mov ecx,[rax+_SecBuffer.cbBuffer]
								mov rsi,[rax+_SecBuffer.pvBuffer]
								jmp process_data
							;	int 3
							;	add @deccount,rcx
							;	cld
							;	rep movsb
						
							.endif
							add rax,sizeof _SecBuffer
							dec r8
						.endw
						
						
						lea rax,@temp_buffer_for_list
						mov r8,4
				
						mov rdi,_precv_buffer
						mov @temp_ip_buffer,rdi
						.while <<test r8,r8>>,GREATER?		;未解密的数据下次一并解密，需要调整接收指针,也可以再解密一次;也有可能:没有需要解密的数据 
					
							.if <<cmp [rax+_SecBuffer.BufferType],SECBUFFER_EXTRA>>,zero?	;The security package uses this value to indicate the number of extra or unprocessed bytes in a message.
						
								mov ecx,[rax+_SecBuffer.cbBuffer]
								mov rsi,[rax+_SecBuffer.pvBuffer]
								cld
								rep movsb
								mov @EncryptMessage_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
								mov @EncryptMessage_SecBufferDesc_buffer.cBuffers,4
								lea rax,@temp_buffer_for_list
								mov @EncryptMessage_SecBufferDesc_buffer.pBuffers,rax
								mov @temp_ip_buffer,rdi
							.endif
							add rax,sizeof _SecBuffer
							dec r8
						.endw
				
						.if <<cmp rdi,_precv_buffer>>,nozero? ;有需要解密的数据 
							;再解密一次
							jmp _againdec
						.endif
						;再recv一点数据
						.break
				
					.elseif <<cmp eax,SEC_E_INCOMPLETE_MESSAGE>>,zero?	;equ 80090318hhe data in the input buffer is incomplete. The application needs to read more data 
										;from the server and call DecryptMessage (Schannel) again.;个人理解：：仅仅为了避免多次调用这个函数
										;这里有个问题：如果服务端一直返回0数据，那么就会死循环
											
						;.if  <<cmp @retry_count ,10>>,greater?
										;我们的处理就是忽略这个请求！也就是说已经连续10次没有读到数据了，那就别指望服务端会提供数据了
						;	invoke logout,addr atext (_error_server,"服务端一直返回0数据,虽然连接没有断开，我们主动断开吧！"),sizeof _error_server
						;	jmp @exit
						;.endif	
						invoke logout,addr atext (_error_INCOMPLETE_MESSAGE_server,"需要更多的数据，继续recv...."),sizeof _error_INCOMPLETE_MESSAGE_server	
						;invoke Sleep,100		
						.break		
					;	.if <<cmp [rax+_SecBuffer.BufferType],SECBUFFER_MISSING>>,zero?
						
					;	lea rax,@temp_buffer_for_list
					;	mov ecx,[rax+_SecBuffer.cbBuffer]		;这里应该是总共需要这么多的数据才能完成本次请求。
				
					;	lea rdi,EncryptMessage_recv_buffer
					;	mov rdi,_precv_buffer
					;	add rdi,rcx
					;	mov @temp_ip_buffer,rdi
					;	.endif
					.elseif <<cmp eax,SEC_E_DECRYPT_FAILURE>>,zero?;无法解密指定的数据（The specified data could not be decrypted
						invoke logout,addr atext (_error_SEC_E_DECRYPT_FAILURE_server,"无法解密指定的数据"),sizeof _error_SEC_E_DECRYPT_FAILURE_server	
						jmp @exit
						
					.elseif <<cmp eax,SEC_E_CONTEXT_EXPIRED>>,zero?;已失效的上下文
						jmp process_data
					.else
						nop
						nop
						nop
						nop
						invoke logout,addr atext (_error_unknown_server,"未知错误"),sizeof _error_unknown_server
						mov rax,0
						jmp @exit
					.endif	
				.endw
			.else
				mov rax,0
				jmp @exit	
			.endif		
		.endw			
		
		
						process_data:
							mov r8,@deccount
							sub r8,sizeof Content_Length-1
							mov @content_length_offset_lehgth,0
							mov @data_size,0
							mov rbx,0
					
							.while <<test r8,r8>>,GREATER?	;是Content_Length 类型的长度吗？
								mov rdi,@pdecrypt_buffer
								lea rsi,Content_Length		;检测数据长度	；Content_Length 			db "Content-Length: ",0
					
								lea rdi,[rdi+rbx]
								mov rcx,sizeof Content_Length-1
								cld
								repz cmpsb
								.if zero?		
							
									mov rsi,@pdecrypt_buffer
									mov rax,rdi
							
									sub rax,rsi
									mov r12,@deccount
									sub r12,rax	;剩余可读的有效内存
									sub r12,4	;0a0d0a0d长度
									mov rbx,0
								@@:	
									.while <<test r12,r12>>,greater?	;剩余可读的有效内存里有没有完整的数据长度
										.if << cmp word ptr [rdi+rbx],0a0dh>>,zero?;Content_Length类型的长度后面紧跟1个回车换行 0D0A
											;有完整的数据长度
											mov r8,rbx
											invoke asciitoint,rdi,r8
											mov @content_length_offset_lehgth,rax;计算出数据长度
											add @data_size,rax
											
											.while <<test r12,r12>>,greater?
												;找到标头结束标志，以后就是需要的数据,每个标头都以回车换行 0D0A结束，所有的标头结束 也是回车换行 0D0A ，所以两个回车换行 （0D0A0D0A）之后说是数据的开始处
											
												.if << cmp dword ptr [rdi+rbx],0a0d0a0dh>>,zero?
													
													lea rdi,[rdi+rbx+4];+4 == 0a0d0a
													mov rsi,rdi
													mov rdi,@heap_mid_buffer; heap_recv_gps_size
													mov rcx,@content_length_offset_lehgth;
													heap_recv_gps_size	equ 1280*720*4
													.if <<cmp @content_length_offset_lehgth,heap_recv_gps_size>>,less?
														cld
														rep movsb
													.endif
													.break
									
													;invoke logout,addr atext(_Content_Length_error,"Content_Length结束标志错误没有0d0a"),sizeof _Content_Length_error	
												.endif
												inc rbx
												dec r12
											.endw
											.break
										.endif
										inc rbx
										dec r12
									.endw
									.break
								.endif
								inc rbx
								dec r8
							.endw
							
							and @flags_chunked,0
							mov r8,@deccount
							sub r8,Transfer_Encoding_size
							mov rdx,0
							.while <<test r8,r8>>,GREATER?		;是块状类型的长度吗？
								mov rdi,@pdecrypt_buffer
								lea rsi,Transfer_Encoding		;检测数据长度
					
								lea rdi,[rdi+rdx]
								mov rcx,Transfer_Encoding_size	;"Transfer-Encoding: chunked od oa  "格式的长度;天地图网站
								cld
								repz cmpsb
								.if zero?		;找到块状标志 
									
									.while  <<test r8,r8>>,GREATER?	
							
										.if << cmp dword ptr [rdi],0a0d0a0dh>>,zero?;两个回车换行 0D0A 0D0A 之后就是块开始标志了,0d 0a 0d 0a	 61 0d-0a 1f 8b 08 00 00 00 00 00 00 00 0d 0a 32 66 66-34 0d 0a 
																																				;61= a(10字节)							;10字节之后结束标志
																																														;32 66 66 34== 2ff4h 下一个块长度
											add rdi,4
											.break
										.else
											inc rdi
										.endif
										dec r8
									.endw
							
									mov rcx,r8;@deccount	; 总共解密的有效数据
									mov rbx,0
							
								@@:	
									.while <<cmp rcx,0>>,greater?	;剩余可读的有效内存里有没有完整的数据长度 把检测到的数据拷贝到 @heap_mid_buffer
										and @flags_chunked,0
								
									;	.if << cmp byte ptr [rdi+rbx],"0">>,zero?;块结束标志，后面的不需要了 如果是"b00"呢？参考 rerror.bmp
														
									;		.break
									;	.endif
								
										.if << cmp byte ptr [rdi+rbx],0dh>>,zero?
									
											.if << cmp ecx,1>>,above?
									
												.if << cmp byte ptr [rdi+rbx+1],0ah>>,zero?;Transfer-Encoding: chunked od oa od oa 之后是数据的长度是16进制ASCII表示的，长度之后是ODOA结束
												;有完整的数据长度
											
											
													mov @chunked_offset_in_all_recv,rdi
											
													add @chunked_offset_in_all_recv,rbx
													inc @chunked_offset_in_all_recv	;跳过0D0A
													inc @chunked_offset_in_all_recv
											
													mov rsi,@pdecrypt_buffer
													sub @chunked_offset_in_all_recv,rsi
											
											
													mov r9,rbx
											
													mov rbx,0
											
													mov rax,0
													.while <<test r9,r9>>,GREATER?	;计算@flags_chunked;块大小
												
														shl @flags_chunked,4 ;块状用16进制ASCII表示
												
														mov al,[rdi+rbx]
														.if <<cmp al,"f">>,ABOVE?
													
															.break
														.endif	
												
														.if <<cmp al,"0">>,BELOW?
													
															.break
														.endif	
														.if <<cmp al,"a">>,ABOVE?||EQUAL?
												
															.if <<cmp al,"f">>,BELOW?||EQUAL?
																SUB AL,20H
																sub al,30h
																SUB AL,7
															.else
														
																.break	
															.endif
												
														.elseif <<cmp al,"A">>,ABOVE?||EQUAL?
												
															.if <<cmp al,"F">>,BELOW?||EQUAL?
																sub al,30h
																SUB AL,7
															.else
														
																.break	
															.endif
												
														.elseif <<cmp al,"0">>,ABOVE?||EQUAL?
												
															.if <<cmp al,"9">>,BELOW?||EQUAL?
														
																sub al,"0"
														
															.else
														
																.break
															.endif
														.else
													
															.break
														.endif
														or @flags_chunked,rax
												
														inc rbx
														dec r9
													.endw
											
													mov rdi,@heap_mid_buffer
													add rdi,@chunked_offset_lehgth;第一次计算时为0
													mov rcx,@flags_chunked;本块大小
											
													add @chunked_offset_lehgth,rcx
													mov rsi,@pdecrypt_buffer
													add rsi,@chunked_offset_in_all_recv
											
											
													cld
													rep movsb
											
													;;;;继续检测，或许有很多块
											
													.if <<cmp word ptr  [rsi],0a0dh>>,nozero?;每个块都是0D0A结束
														;invoke MessageBox,
												
												
														invoke logout,addr atext(_chunked_error,"块状结束标志错误没有0d0a"),sizeof _chunked_error
														jmp @exit
												
												
													.endif
											
													inc @chunked_offset_in_all_recv	;跳过0D0A
													inc @chunked_offset_in_all_recv	;每个块都是0D0A结束
													mov rcx,@flags_chunked;本块大小
													add @chunked_offset_in_all_recv,rcx
											
													mov rdi,@pdecrypt_buffer
													add rdi,@chunked_offset_in_all_recv
															
													mov rbx,0
													mov rcx,@deccount
													sub rcx,@chunked_offset_in_all_recv
													sub rcx,2;;每个块都是0D0A结束
													jmp @b
											
											
												.else
													and @data_size,0
													.break		
												.endif
										
											.else
												and @data_size,0
												.break	
										
											.endif
									
										.endif
										inc rbx
								
										dec rcx
								
									.endw
									.break
							
								.else	
									inc rdx
					
								.endif
								dec r8
							.endw
					
							mov rax,@chunked_offset_lehgth
							.if <<cmp rax,0>>,nozero?
								mov @data_size,rax
							.endif
					
							mov r8,@deccount	;解密计数
							sub r8,sizeof Content_Encoding-1
				
							and @flags_deflate,0
							and @flags_gzip,0
							mov rbx,0
							.while <<test r8,r8>>,GREATER?;检测网页内容采用哪种压缩
								mov rdi,@pdecrypt_buffer
								lea rsi,Content_Encoding		
					
								lea rdi,[rdi+rbx]
								mov rcx,sizeof Content_Encoding-1
								cld
								repz cmpsb
								.if zero?		
						
									push rdi
									lea rsi,gzip_compress
									mov rcx,sizeof gzip_compress-1
									cld
									repz cmpsb	;是gzip压缩吗？
									.if zero?
										pop rdi
										or @flags_gzip,1
										and @flags_deflate,0
									.else
										pop rdi
										lea rsi,deflate__compress
										mov rcx,sizeof deflate__compress-1
										cld
										repz cmpsb
										.if zero?
											and @flags_gzip,0
											or @flags_deflate,1
								
										.endif
						
									.endif
						
									.break
								.else	
									inc rbx
					
								.endif
								dec r8
					
							.endw
			
							mov rcx,@data_size
							.if <<cmp @data_size,0>>,ABOVE?
				
								;已经接收完了，其余的不需要了
								nop
								mov rcx,@data_size
								mov rbx,@uncompress_count
								mov rsi,_precv_buffer
								mov rdi,@heap_mid_buffer
								mov rax,_precv_buffer_length
								mov @uncompress_count,rax
					
								;mov rax,@flags_deflate
								;mov rcx,@flags_gzip
								.if <<cmp @flags_deflate,1>>,zero?
									invoke uncompress,_precv_buffer,addr @uncompress_count,rdi,@data_size		;这个是ZLIB内部的
								.elseif  <<cmp @flags_gzip,1>>,zero?
									invoke uncommpress,_precv_buffer,addr @uncompress_count,rdi,@data_size
								.else
									mov rsi,@heap_mid_buffer	
									mov rcx,@data_size
									mov rdi,_precv_buffer
									cld
									rep movsb
									mov rax,0
								.endif
								mov @flags,1
					
								.if <<test rax,rax>>,zero?
						
									;解压成功
									nop
									mov r8, @uncompress_count
									sub r8,sizeof access_token_token-1	
						
								;	invoke SetDlgItemTextA,hWnd_main,1004,_precv_buffer
									;如果还有剩余的数据，那就继续接收
							comment ~
						.while			
							@@@again_:
							and @readcount,0
							invoke ioctlsocket,@hSocket,FIONREAD,addr @readcount ;阻塞模式 在一次recv()中所接收的所有数据量。
                     					   ; 这通常与套接口中排队的数据总量相同。
                     					   ; 如果S是SOCK_DGRAM 型，则FIONREAD
                     					   ; 返回套接口上排队的第一个数据报大小。	
                        
                     						   ;正常返回0
                        
           						.if <<test eax,eax>>,zero?		
                	
                       				 .if <<cmp @readcount,0>>,zero?	;客户端connect 之后 如果没有发送数据 就会 @readcount== 0 
				
										invoke Sleep,100
				
										inc @retry_count
				
										.if  <<cmp @retry_count ,10>>,less?||equal?	;
											mov rcx,@retry_count
											lea rsi,@instrbuffer
						
											mov [rsi],rcx
						
											invoke wvsprintfA,addr @tempbuffer,addr atext(network_tail_time_https,"ioctlsocket 已经成功尾部清理调用第%d次",0dh,0ah),rsi
											invoke lstrlenA,addr @tempbuffer
											mov r8,rax
											invoke logout,addr @tempbuffer,r8
										;	invoke WriteFile,hfile_error_log,addr @tempbuffer,r8,addr  @return_count,0
											jmp @@@again_
										.else
											
											.break
										.endif
				
									.else
										mov rdi,@pdecrypt_buffer
										mov rax,@readcount
					
										invoke _recv,@hSocket,rdi,@readcount,0
									
										jmp @@@again_
					
									.endif
								
								.else
									.break
								.endif
								
						.endw
						comment ~
									mov rax,_returnbody_lehgth
									mov rcx,@uncompress_count
									mov [rax],rcx
									mov rax,1;接收成功
						
								.else
									mov rax,0
						
					
								.endif
				
							.else
								mov rax,0
					
							.endif
		
		
		
	@exit:
	invoke GetProcessHeap
	invoke HeapFree,rax,0,@heap_mid_buffer
	mov rax,@flags
	add rsp,80h
	
	;lea rax,precv_buffer
	
	ret

wait_and_recv_data_for_https endp

connect_SecurityContext  proc <:qword,:qword,:qword,qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_pTargetName:qword,_pTargetName_wide:qword,_pCredHandle:qword,_pCtxtHandle:qword,_ptimstamp:qword
	LOCAL @hSocket:qword
	LOCAL @readcount:qword
	LOCAL @retry_count:qword
	LOCAL @temp_ip_buffer:qword	;缓冲区指针
	
	LOCAL @ppChainContext :qword
	LOCAL @pCertContext:qword
	LOCAL @pbcomputedhsah [20h]:byte
	LOCAL @pcbcomputedhash:qword
	LOCAL @psz		[100h]:byte
	LOCAL @count_input	:qword
	LOCAL  @temp_ip_buffer_input:qword
	LOCAL @SecPkgContext_StreamSizes_buffer :SecPkgContext_StreamSizes
	LOCAL @SCHANNEL_CRED_buffer	 :_SCHANNEL_CRED
	LOCAL @flags:qword
	LOCAL @pfContextAttr 			[10h]:qword
	LOCAL @output_SecBufferDesc_buffer		:_SecBufferDesc
	LOCAL @output_SecBuffer_buffer			:_SecBuffer
	LOCAL @input_SecBufferDesc_buffer		:_SecBufferDesc
	LOCAL @input_SecBuffer_buffer			:_SecBuffer
	LOCAL @temp_buffer_for_list			[5]:_SecBuffer; 5 dup (<?>
	LOCAL @temp_buffer_for_list_input		[5]:_SecBuffer;_SecBuffer 5 dup (<?>)
	
		mov @hSocket,rcx
		mov _pTargetName,rdx
		mov _pTargetName_wide,r8	
		mov _pCredHandle,r9
		sub rsp,100h
		and @flags,0
		invoke RtlZeroMemory,addr @SCHANNEL_CRED_buffer,sizeof @SCHANNEL_CRED_buffer
		mov @SCHANNEL_CRED_buffer.dwVersion,SCHANNEL_CRED_VERSION
		SP_PROT_SSL3_CLIENT equ 20h
		SP_PROT_SSL2_CLIENT equ  8
		mov @SCHANNEL_CRED_buffer.grbitEnabledProtocols,SP_PROT_TLS1_CLIENT+SP_PROT_TLS1_1_CLIENT+SP_PROT_TLS1_2_CLIENT
		;mov @SCHANNEL_CRED_buffer.dwFlags,40h;SCH_CRED_MANUAL_CRED_VALIDATION+SCH_CRED_NO_DEFAULT_CREDS;SCH_CRED_USE_DEFAULT_CREDS == 40
		invoke AcquireCredentialsHandleA,0,addr sspi,SECPKG_CRED_OUTBOUND,0,addr  @SCHANNEL_CRED_buffer,0,0,_pCredHandle,_ptimstamp
			
			
		.if <<cmp rax, SEC_E_OK>>,nozero?
				
			jmp exit
		.endif
		mov @output_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
		mov @output_SecBufferDesc_buffer.cBuffers,1	;缓冲区个数
		lea rax,@output_SecBuffer_buffer
		mov @output_SecBufferDesc_buffer.pBuffers,rax
		
		mov @output_SecBuffer_buffer.cbBuffer,0;sizeof output_pOutput_buffer	;函数返回后，这里会有接收的数据大小
		mov @output_SecBuffer_buffer.BufferType,SECBUFFER_EMPTY;SECBUFFER_TOKEN;== 2
		;lea rax,@output_pOutput_buffer	
		mov @output_SecBuffer_buffer.pvBuffer,0;rax
		flages equ  ISC_REQ_SEQUENCE_DETECT +ISC_REQ_REPLAY_DETECT + ISC_REQ_CONFIDENTIALITY  + ISC_REQ_STREAM+ISC_REQ_ALLOCATE_MEMORY+ISC_REQ_USE_SUPPLIED_CREDS
		;flages equ ISC_REQ_STREAM+ISC_REQ_CONFIDENTIALITY+ISC_REQ_REPLAY_DETECT+ISC_REQ_SEQUENCE_DETECT+ISC_REQ_INTEGRITY+ISC_REQ_MUTUAL_AUTH;ISC_REQ_ALLOCATE_MEMORY+
			;ISC_REQ_USE_SUPPLIED_CREDS:Schannel不得尝试自动为客户端提供凭据 ;ISC_REQ_CONFIDENTIALITY 使用EncryptMessage函数加密消息。ISC_REQ_REPLAY_DETECT:检测使用EncryptMessage或MakeSignature函数编码的重播消息。ISC_REQ_SEQUENCE_DETECT:检测不按顺序接收的消息。
			;invoke InitializeSecurityContextA,addr CredHandle,addr CtxtHandle,0,ISC_REQ_STREAM+ISC_REQ_USE_SUPPLIED_CREDS+ISC_REQ_CONFIDENTIALITY+ISC_REQ_REPLAY_DETECT+ISC_REQ_SEQUENCE_DETECT,\
		invoke InitializeSecurityContextA,_pCredHandle,0,_pTargetName,flages,\
							0,0,0,0, _pCtxtHandle,addr @output_SecBufferDesc_buffer,addr @pfContextAttr,0
								
							
			
		.if <<cmp rax,SEC_I_CONTINUE_NEEDED>>,nozero?;第一次调用应该是必需返回SEC_I_CONTINUE_NEEDED
			;/* send initial handshake data which is now stored in output buffer */
			;The client must send the output token to the server and wait for a return token. The returned token is then passed in another call to InitializeSecurityContext (Schannel). The output token can be empty.
			jmp exit
		
		.endif
			
		
		lea rbx,@output_SecBuffer_buffer
		mov r8d,@output_SecBuffer_buffer.cbBuffer
		mov rax,@output_SecBuffer_buffer.pvBuffer
		nop
		invoke _send,@hSocket, @output_SecBuffer_buffer.pvBuffer,r8,0
		.if <<test rax,rax>>,zero?
			.if <<cmp @output_SecBuffer_buffer.pvBuffer,0>>,nozero?
				invoke FreeContextBuffer,@output_SecBuffer_buffer.pvBuffer
			.endif
			
			jmp exit
		.endif
		invoke FreeContextBuffer,@output_SecBuffer_buffer.pvBuffer
		
		and @readcount,0	
		and @retry_count,0	
		lea rdi,recv_token_buffer;这个缓冲接收服务器返回的令牌
		mov @temp_ip_buffer,rdi
		.while
		again_:	
			and @readcount,0
			invoke ioctlsocket,@hSocket,FIONREAD,addr @readcount ;阻塞模式 在一次recv()中所接收的所有数据量。
                        ; 这通常与套接口中排队的数据总量相同。
                        ; 如果S是SOCK_DGRAM 型，则FIONREAD
                        ; 返回套接口上排队的第一个数据报大小。	
                        
                        ;正常返回0
                        
           		.if <<test eax,eax>>,zero?
                	
                       		 .if <<cmp @readcount,0>>,zero?	;客户端connect 之后 如果没有发送数据 就会 @readcount== 0 
				
					
					invoke Sleep,100
				
					inc @retry_count
				
					.if  <<cmp @retry_count ,10>>,less?||equal?	;
				
						jmp again_
				
					.endif
				
				.else
					mov rdi,@temp_ip_buffer
					mov rax,@readcount
					invoke _recv,@hSocket,rdi,@readcount,0
					.if <<test rax,rax>>,zero?
					
						jmp exit
					.endif
					mov rdi,@temp_ip_buffer
					add rdi,@readcount
					mov @temp_ip_buffer,rdi
					and @retry_count,0
					and @readcount,0
				.endif
			.else
				mov rax,0
				jmp exit	
			.endif
			
			
		
			
			mov @input_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
			mov @input_SecBufferDesc_buffer.cBuffers,2	;缓冲区个数
			lea rax,@temp_buffer_for_list
			mov @input_SecBufferDesc_buffer.pBuffers,rax
			
			lea rdi,recv_token_buffer
			mov rcx,@temp_ip_buffer
			sub rcx,rdi
			mov [rax+_SecBuffer.cbBuffer],ecx;recv接收的数据
			
			mov [rax+_SecBuffer.BufferType],SECBUFFER_TOKEN;== 2
			lea rsi,recv_token_buffer
			mov [rax+_SecBuffer.pvBuffer],rsi
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			mov @output_SecBufferDesc_buffer.ulVersion,SECBUFFER_VERSION;== 0
			mov @output_SecBufferDesc_buffer.cBuffers,3	;缓冲区个数
			lea rax,@temp_buffer_for_list_input
			mov @output_SecBufferDesc_buffer.pBuffers,rax
			
			
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
			add rax,sizeof _SecBuffer
			mov [rax+_SecBuffer.cbBuffer],0;SECBUFFER_EMPTY               0
			
			mov [rax+_SecBuffer.BufferType],0
			
			mov [rax+_SecBuffer.pvBuffer],0
			
				
			
		
			invoke InitializeSecurityContextA,_pCredHandle,_pCtxtHandle,0,flages,\
								0,0,addr @input_SecBufferDesc_buffer,0,\
								0,addr @output_SecBufferDesc_buffer,addr @pfContextAttr,0
							
			.if <<cmp eax ,SEC_E_OK>>,zero?	;成功了
				
				;The security context was successfully initialized. There is no need for another InitializeSecurityContext (Schannel) call.
				; If the function returns an output token, that is, if the SECBUFFER_TOKEN in pOutput is of nonzero length, that token must be sent to the server.
				
				
				lea rax,@pfContextAttr
				mov rax,_pCtxtHandle
				
				lea rax,@temp_buffer_for_list_input
				nop
				mov @temp_ip_buffer_input,rax
				mov @count_input,3
				.while <<cmp @count_input,0>>,greater?
				
				
					.if << cmp [rax+_SecBuffer.BufferType],SECBUFFER_TOKEN>>,zero?
				
						.if << cmp [rax+_SecBuffer.cbBuffer],0>>,greater?
					
							.if << cmp [rax+_SecBuffer.pvBuffer],0>>,greater?
								mov r8d,[rax+_SecBuffer.cbBuffer]
								mov rdx,[rax+_SecBuffer.pvBuffer]
								
								nop
								invoke _send,@hSocket, rdx,r8,0
								.if <<test rax,rax>>,zero?
					
									.break
								.endif
							;	mov rax,@temp_ip_buffer_input
							;	mov rcx,[rax+_SecBuffer.pvBuffer]
							;	invoke FreeContextBuffer,rcx
							.endif
						.endif
					.endif
					add @temp_ip_buffer_input,sizeof _SecBuffer
					mov rax,@temp_ip_buffer_input
					dec @count_input
				.endw
				mov @flags,1
				.break
				
			.elseif <<cmp eax ,SEC_E_INCOMPLETE_MESSAGE>>,zero?	;Data for the whole message was not read from the wire.

										;When this value is returned, the pInput buffer contains a SecBuffer structure 
										;with a BufferType member of SECBUFFER_MISSING. The cbBuffer member of SecBuffer 
										;contains a value that indicates the number of additional bytes that the function 
										;must read from the client before this function succeeds. While this number is not always accurate, 
										;using it can help improve performance by avoiding multiple calls to this function.
										
										;"schannel: received incomplete message, need more data\n"));
										;未从连线读取整条消息的数据。返回此值时，pInput缓冲区包含一个SecBuffer结构，其中缺少SecBuffer_的BufferType成员。SecBuffer的cbBuffer成员包含一个值，
										;该值指示在该函数成功之前该函数必须从客户端读取的附加字节数。虽然这个数字并不总是准确的，但是使用它可以避免多次调用这个函数，从而帮助提高性能。
										
										;个人理解：：仅仅为了避免多次调用这个函数
										
										
				.if  <<cmp @retry_count ,10>>,greater?
				
										;我们的处理就是忽略这个请求！也就是说已经连续10次没有读到数据了，那就别指望服务端会提供数据了
					invoke logout,addr atext (_error_connect_SecurityContext,"证书生成过程中服务端一直返回0数据,虽然连接没有断开，我们主动断开吧！"),sizeof _error_connect_SecurityContext
					.break
					
					
				.endif												
				
			;	lea rax,@temp_buffer_for_list_input
			;	mov ecx,[rax+_SecBuffer.cbBuffer]		;这里应该是总共需要这么多的数据才能完成本次请求。
				
			
				
			;.elseif <<cmp eax,SEC_I_INCOMPLETE_CREDENTIALS>>,zero?	
			;	nop	
				
			.elseif <<cmp eax,SEC_I_COMPLETE_NEEDED>>,zero?						
				nop						; InitializeSecurityContext (Digest) 时有这种情况
			.elseif <<cmp eax,SEC_I_CONTINUE_NEEDED>>,zero?	;这种情况是我们的input_SecBufferDesc_buffer 指定的缓冲区里的数据没有处理完，需要继续处理
							;send handshake token to server */
				lea rax,@temp_buffer_for_list_input
				mov @temp_ip_buffer_input,rax
				mov @count_input,3
				.while <<cmp @count_input,0>>,greater?
				
				
					.if << cmp [rax+_SecBuffer.BufferType],SECBUFFER_TOKEN>>,zero?
				
						.if << cmp [rax+_SecBuffer.cbBuffer],0>>,greater?
					
							.if << cmp [rax+_SecBuffer.pvBuffer],0>>,greater?
								mov r8d,[rax+_SecBuffer.cbBuffer]
								mov rdx,[rax+_SecBuffer.pvBuffer]
								nop
								invoke _send,@hSocket, rdx,r8,0
								.if <<test rax,rax>>,zero?
					
									.break
								.endif
								
							.endif
						.endif
					.endif
					add @temp_ip_buffer_input,sizeof _SecBuffer
					mov rax,@temp_ip_buffer_input
					dec @count_input
				.endw
				
				
				lea rax,@temp_buffer_for_list_input
				
				add rax,sizeof _SecBuffer
				mov ecx,[rax+_SecBuffer.BufferType]
				.if <<cmp ecx,SECBUFFER_EXTRA>>,zero?;The security package uses this value to
                                               				 ;  indicate the number of extra or
                                               				 ;  unprocessed bytes in a message.
					mov ecx,[rax+_SecBuffer.cbBuffer];未处理的数据大小
					
					mov rsi,[rax+_SecBuffer.pvBuffer]
					
					add rsi,rcx
					lea rdi,recv_token_buffer
					cld
					rep movsb
					
					and @readcount,0	
					and @retry_count,0	
				
					mov @temp_ip_buffer,rdi
					
					
				.else
					and @readcount,0	
					and @retry_count,0	
					lea rdi,recv_token_buffer
					mov @temp_ip_buffer,rdi	
					
				.endif
			
			.else
				.break
				
			.endif
			
			
			mov @count_input,3
			lea rax,@temp_buffer_for_list_input
			mov @temp_ip_buffer_input,rax
			.while <<cmp @count_input,0>>,greater?
				
			
				.if << cmp [rax+_SecBuffer.cbBuffer],0>>,greater?
					
					.if << cmp [rax+_SecBuffer.pvBuffer],0>>,greater?
					
						mov rax,@temp_ip_buffer_input
						mov rcx,[rax+_SecBuffer.pvBuffer]
						invoke FreeContextBuffer,rcx
					.endif
				.endif
			
				add @temp_ip_buffer_input,sizeof _SecBuffer
				mov rax,@temp_ip_buffer_input
				dec @count_input
			
			.endw
			
			
			
			
		.endw	
		
			
			mov @count_input,3
			lea rax,@temp_buffer_for_list_input
			mov @temp_ip_buffer_input,rax
			.while <<cmp @count_input,0>>,greater?
				
			
				.if << cmp [rax+_SecBuffer.cbBuffer],0>>,greater?
					
					.if << cmp [rax+_SecBuffer.pvBuffer],0>>,greater?
					
						mov rax,@temp_ip_buffer_input
						mov rcx,[rax+_SecBuffer.pvBuffer]
						invoke FreeContextBuffer,rcx
					.endif
				.endif
			
				add @temp_ip_buffer_input,sizeof _SecBuffer
				mov rax,@temp_ip_buffer_input
				dec @count_input
			
			.endw
			
			
			
			
			
			jmp exit
			
		.if 	zero?
			;;;;证书的检验还是有问题，以后还要处理
			
			SECPKG_ATTR_REMOTE_CERT_CONTEXT equ  53h
			invoke QueryContextAttributesA,_pCtxtHandle,SECPKG_ATTR_REMOTE_CERT_CONTEXT,addr @pCertContext
			.if <<cmp rax,0>>,nozero?
				mov rax,0
				jmp exit
			.endif
			
			mov CERT_CHAIN_ENGINE_CONFIG_buffer.cbSize,sizeof CERT_CHAIN_ENGINE_CONFIG
			mov CERT_CHAIN_ENGINE_CONFIG_buffer.cAdditionalStore,1
			mov rsi,@pCertContext
			lea rax,[rsi+CERT_CONTEXT.hCertStore]
			mov CERT_CHAIN_ENGINE_CONFIG_buffer.rghAdditionalStore,rax
			
			
			invoke CertCreateCertificateChainEngine,addr CERT_CHAIN_ENGINE_CONFIG_buffer,addr phChainEngine		;使用CertCreateCertificateChainEngine创建搜索引擎。为应用程序创建一个新的非却省的链引擎
			.if <<cmp rax,0>>,zero?
				nop
				jmp exit
			.endif
			
			
			nop
			mov CERT_CHAIN_PARA_buffer.cbSize,sizeof CERT_CHAIN_PARA_buffer
			mov CERT_CHAIN_PARA_buffer.RequestedUsage.dwType,0		;USAGE_MATCH_TYPE_AND 0x00000000 #define USAGE_MATCH_TYPE_OR  0x00000001; an empty Usage member means that any nested usage in the chain will work.
					
			mov CERT_CHAIN_PARA_buffer.RequestedUsage.Usage.cUsageIdentifier,0
			lea rax,Server_Authentication
			mov CERT_CHAIN_PARA_buffer.RequestedUsage.Usage.rgpszUsageIdentifier,rax
			
			
			lea rax,@ppChainContext
			invoke CertGetCertificateChain,phChainEngine, @pCertContext,0,0,addr CERT_CHAIN_PARA_buffer,0,0,rax	;使用CertGetCertificateChain为每个证书构建证书链。从最后一个证书建立一个上下文链表
			.if <<cmp rax,0>>,zero?
				
				
				
				
				jmp exit
			.endif
			
			
			
			mov rsi,@ppChainContext
			mov eax,[rsi+CERT_CHAIN_CONTEXT.TrustStatus.dwErrorStatus]
				
			.if <<cmp eax, CERT_TRUST_NO_ERROR>>,zero?
				;   printf("No error found for this certificate or chain.\n");	
			.elseif	<<cmp eax, CERT_TRUST_IS_NOT_TIME_VALID>>,zero?	
					
				;  printf("This certificate or one of the certificates in the " "certificate chain is not time-valid.\n");	
			
			.elseif	<<cmp eax, CERT_TRUST_IS_REVOKED>>,zero?	
				; printf("Trust for this certificate or one of the certificates "
        			; "in the certificate chain has been revoked.\n");
			.elseif	<<cmp eax,CERT_TRUST_IS_NOT_SIGNATURE_VALID>>,zero?	
				; printf("The certificate or one of the certificates in the "
         			;"certificate chain does not have a valid signature.\n");
				;
			.elseif	<<cmp eax, CERT_TRUST_IS_NOT_VALID_FOR_USAGE>>,zero?	
				; printf("The certificate or certificate chain is not valid "
      				;   "in its proposed usage.\n");
			.elseif	<<cmp eax,CERT_TRUST_IS_UNTRUSTED_ROOT>>,zero?	
				; printf("The certificate or certificate chain is based "
       				;  "on an untrusted root.\n");
			.elseif	<<cmp eax,CERT_TRUST_REVOCATION_STATUS_UNKNOWN>>,zero?	
				;   printf("The revocation status of the certificate or one of the"
        			; "certificates in the certificate chain is unknown.\n");
			.elseif	<<cmp eax,CERT_TRUST_IS_CYCLIC>>,zero?	
				; printf("One of the certificates in the chain was issued by a "
        			; "certification authority that the original certificate "
        			; "had certified.\n");
			.elseif	<<cmp eax,CERT_TRUST_IS_PARTIAL_CHAIN>>,zero?	
				; printf("The certificate chain is not complete.\n");
				
			.elseif	<<cmp eax,CERT_TRUST_CTL_IS_NOT_TIME_VALID>>,zero?	
				; printf("A CTL used to create this chain was not time-valid.\n");
			.elseif	<<cmp eax, CERT_TRUST_CTL_IS_NOT_SIGNATURE_VALID>>,zero?	
				; printf("A CTL used to create this chain did not have a valid " "signature.\n");
			.elseif	<<cmp eax,CERT_TRUST_CTL_IS_NOT_VALID_FOR_USAGE>>,zero?	
				; printf("A CTL used to create this chain is not valid for this " "usage.\n");
														
			.endif
			
			mov rsi,@ppChainContext
			mov eax,[rsi+CERT_CHAIN_CONTEXT.TrustStatus.dwInfoStatus]
			.if <<cmp eax,0>>,zero?
				; printf("No information status reported.\n");
			.elseif	<<cmp eax,CERT_TRUST_HAS_EXACT_MATCH_ISSUER>>,zero?		
				; printf("An exact match issuer certificate has been found for "
         			;"this certificate.\n");
			.elseif	<<cmp eax,CERT_TRUST_HAS_KEY_MATCH_ISSUER>>,zero?	
				; printf("A key match issuer certificate has been found for this "
       				; "certificate.\n");
			.elseif	<<cmp eax,CERT_TRUST_HAS_NAME_MATCH_ISSUER>>,zero?			
				;printf("A name match issuer certificate has been found for this "
       				; "certificate.\n");
       			.elseif	<<cmp eax,CERT_TRUST_IS_SELF_SIGNED>>,zero?	
       				; printf("This certificate is self-signed.\n");
       			.elseif	<<cmp eax,CERT_TRUST_IS_COMPLEX_CHAIN>>,zero?	
       				; printf("The certificate chain created is a complex chain.\n");		
			.endif
			
			
			
			CERT_CHAIN_POLICY_SSL  equ 4		;Implements the SSL client/server chain policy verification checks
			
			
			mov CERT_CHAIN_POLICY_PARA_buffer.cbSize,sizeof CERT_CHAIN_POLICY_PARA
			mov CERT_CHAIN_POLICY_PARA_buffer.dwFlags,0
			lea rax,HTTPSPolicyCallbackData_buffer
			mov CERT_CHAIN_POLICY_PARA_buffer.pvExtraPolicyPara,rax
			
			mov HTTPSPolicyCallbackData_buffer.DUMMYUNIONNAME.cbSize,sizeof HTTPSPolicyCallbackData
			mov HTTPSPolicyCallbackData_buffer.dwAuthType,2	;AUTHTYPE_CLIENT == 1    AUTHTYPE_SERVER == 2
			mov HTTPSPolicyCallbackData_buffer.fdwChecks,0
			mov rax,_pTargetName_wide
			mov HTTPSPolicyCallbackData_buffer.pwszServerName,rax
			
			
			mov CERT_CHAIN_POLICY_STATUS_buffer.cbSize,sizeof CERT_CHAIN_POLICY_STATUS
			invoke CertVerifyCertificateChainPolicy,CERT_CHAIN_POLICY_SSL,@ppChainContext,addr CERT_CHAIN_POLICY_PARA_buffer,addr CERT_CHAIN_POLICY_STATUS_buffer
			.if <<cmp rax,0>>,zero?		;返回值指示函数是否能够检查策略，但不指示策略检查是否失败或通过。通过检查证书链来确定它的完整性
							;如果可以为指定的策略验证链，则返回TRUE并更新pPolicyStatus的dwError成员。dwError为0 (ERROR_SUCCESS或S_OK)表示该链满足指定的策略。
				
				jmp exit
			.endif
			mov eax,CERT_CHAIN_POLICY_STATUS_buffer.dwError	
			CERT_E_UNTRUSTEDROOT equ 800B0109h
			CERT_E_CN_NO_MATCH equ 800B010Fh 
			
			.if  <<cmp eax,0>>,zero? ;dwError为0 (ERROR_SUCCESS或S_OK)表示该链满足指定的策略。
			
			.elseif <<cmp eax,CERT_E_UNTRUSTEDROOT>>,zero? ;正确处理但终止于信任提供者不信任的根证书中的证书链。
				
			.elseif <<cmp eax,CERT_E_CN_NO_MATCH>>,zero?	;证书的CN名称与传递的值不匹配。
				
			.else
				jmp @f	
			.endif
			
			mov rsi,@ppChainContext
			
			mov ecx,[rsi+CERT_CHAIN_CONTEXT.cChain]
			
			.if <<cmp ecx,0>>,zero?		
				
				jmp exit
			.endif
			
			mov rsi,[rsi+CERT_CHAIN_CONTEXT.rgpChain]	;PCERT_SIMPLE_CHAIN
			mov rdi,[rsi+0];CERT_SIMPLE_CHAIN      cChain 指定的多个CERT_SIMPLE_CHAIN结构的指针	 rgpChains[0] is the end certificate simple chain
			mov ecx,[rdi+CERT_SIMPLE_CHAIN.cElement]
			.if <<cmp ecx,0>>,zero?		
				
				jmp exit
			.endif
			
			CALG_SHA	equ 000008004h 
			mov rsi,[rdi+CERT_SIMPLE_CHAIN.rgpElement]
			mov rsi,[rsi+0]	;cElement 指定的多个CERT_CHAIN_ELEMENT 
			mov rdi,[rsi+CERT_CHAIN_ELEMENT.pCertContext]
			
			mov rsi,[rdi+CERT_CONTEXT.pbCertEncoded]
			mov r10d,[rdi+CERT_CONTEXT.cbCertEncoded]
			mov @pcbcomputedhash,14h;20字节
			invoke CryptHashCertificate,0,CALG_SHA,0,rsi,r10,addr @pbcomputedhsah,addr @pcbcomputedhash
			.if <<cmp eax,0>>,zero?		
				
				jmp exit
			.endif
			
			lea rax,@pbcomputedhsah
			
			
			mov rax, [rdi+CERT_CONTEXT.pCertInfo]
			lea rdx,[rax+CERT_INFO.Issuer]	;颁发者
			
			mov ecx,[rdi+CERT_CONTEXT.dwCertEncodingType]
			CERT_X500_NAME_STR equ 3
			invoke CertNameToStrA,rcx,rdx,CERT_X500_NAME_STR,addr @psz,sizeof @psz		
			lea rax,@psz
			
			mov rax, [rdi+CERT_CONTEXT.pCertInfo]
			lea rdx,[rax+CERT_INFO.Subject]	;使用者
			
			mov ecx,[rdi+CERT_CONTEXT.dwCertEncodingType]
			CERT_X500_NAME_STR equ 3
			invoke CertNameToStrA,rcx,rdx,CERT_X500_NAME_STR,addr @psz,sizeof @psz
			lea rax,@psz
			
		@@:	
			
			mov rax, [rdi+CERT_CONTEXT.pCertInfo]
			lea rdx,[rax+CERT_INFO.SerialNumber]	;序列号
		.endif	
			
			
			mov rax,1
		
	invoke CertFreeCertificateChain ,@ppChainContext
	invoke CertFreeCertificateChainEngine,addr phChainEngine
	exit:	
	
	mov rax,@flags
	add rsp,100h
	
	
	ret

connect_SecurityContext endp
disconnect_server_for_https proc uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _hSocket:qword,_pCredHandle:qword,_pCtxtHandle:qword
		LOCAL @hheap:qword
			mov _hSocket,rcx
			mov _pCredHandle,rdx
			mov _pCtxtHandle,r8
			sub rsp,40h
			invoke FreeCredentialsHandle,_pCredHandle
			invoke DeleteSecurityContext,_pCtxtHandle
			invoke shutdown,_hSocket,2;0 不能再读，1不能再写，2 读写都不能。
					
			invoke closesocket,_hSocket
			
		
		
			add rsp,40h
	ret
disconnect_server_for_https endp



connect_server_for_8080 proc	<:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _ipaddress:qword,_port:qword
		LOCAL @stWsa:WSADATA
		LOCAL @stSin:sockaddr_in
		LOCAL @hSocket:qword
		LOCAL @hheap:qword
		LOCAL @timecount:dword
		
			mov _ipaddress,rcx
			mov _port,rdx
			sub rsp,40h
	
			mov @timecount,0
		
		
			invoke	WSAStartup,0202h,addr @stWsa
			@@:
			invoke	socket,AF_INET,SOCK_STREAM,IPPROTO_TCP
			.if << cmp rax,INVALID_SOCKET>>,zero?
				inc @timecount
				invoke Sleep,100
				.if <<cmp @timecount,20>>,greater?
					invoke logout,addr atext (http_WSAStartup_error,"htttp_WSAStartup_error"),sizeof http_WSAStartup_error
					mov eax,0
					jmp exit
				.else
					jmp @b
				.endif
				
			.endif
		
			mov	@hSocket,rax
			invoke setsockopt,@hSocket,SOL_SOCKET, SO_KEEPALIVE,addr _keepAlive,sizeof _keepAlive
			TCP_KEEPIDLE equ 3
			
			TCP_KEEPINTVL equ 4
			
			TCP_KEEPCNT equ 5
			invoke setsockopt ,@hSocket,IPPROTO_TCP, TCP_KEEPIDLE,addr _keepIdle, sizeof _keepIdle
			invoke setsockopt ,@hSocket,IPPROTO_TCP, TCP_KEEPINTVL,addr _keepInterval, sizeof _keepInterval
			invoke setsockopt, @hSocket,IPPROTO_TCP, TCP_KEEPCNT,addr _keepCount, sizeof _keepCount
			
			invoke	inet_addr,_ipaddress;
			.if	<<cmp eax ,INADDR_NONE>>,zero?
				invoke logout,addr atext (_inet_addr_error,"http_inet_addr_error"),sizeof _inet_addr_error
				mov rax,0
				jmp exit
			.endif
			mov	@stSin.sin_addr,eax
			mov	@stSin.sin_family,AF_INET
			mov rax,_port;8080;443
			invoke	htons,rax		;htonl()表示将32位的主机字节顺序转化为32位的网络字节顺序 htons()表示将16位的主机字节顺序转化为16位的网络字节顺序（ip地址是32位的端口号是16位的 ）
			mov	@stSin.sin_port,ax
			mov @timecount,0
		@@:
			invoke	connect,@hSocket,addr @stSin,sizeof @stSin
			.if	cmp <<eax ,SOCKET_ERROR>>,zero?
				invoke	WSAGetLastError
				.if <<cmp eax , WSAEWOULDBLOCK>>,nozero?
					inc @timecount
					invoke Sleep,100
					.if <<cmp @timecount,20>>,greater?
						invoke  logout,addr  atext (_http_again_connect,"http_again_connect?"),sizeof  _http_again_connect
						mov eax,0
						jmp exit
					.else
						jmp @b
					.endif	
				.endif
			.endif
			mov rax,@hSocket
			add rsp,40h
			ret
		exit:	
			mov rax,0
			add rsp,40h
			ret
		
connect_server_for_8080 endp


connect_server_with_ipv6 proc	<:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _ipaddress:qword,_port:qword
		LOCAL @stWsa:WSADATA
		LOCAL @stSin			:sockaddr_in6
		LOCAL @hSocket:qword
		LOCAL @hheap:qword
		LOCAL @timecount:dword
		
			mov _ipaddress,rcx
			mov _port,rdx
			sub rsp,40h
	
			mov @timecount,0
		
		
			invoke	WSAStartup,0202h,addr @stWsa
			@@:
			invoke	socket,AF_INET6,SOCK_STREAM,IPPROTO_TCP
			mov	@hSocket,rax
		
		
			mov rax,_port
			invoke	htons,rax
			mov	@stSin.sin6_port ,ax
			mov	@stSin.sin6_family,AF_INET6
			lea rax ,@stSin.sin6_addr
		
			;invoke inet_pton,AF_INET6,addr adressipv6,addr @stSin.sin6_addr;如果未发生错误， InetPton 函数将返回值 1	将点分十进制的ip地址转化为用于网络传输的数值格式
			invoke inet_pton,AF_INET6,_ipaddress,addr @stSin.sin6_addr;如果未发生错误， InetPton 函数将返回值 1	将点分十进制的ip地址转化为用于网络传输的数值格式
		
			;mov	@stSin.sin6_addr,INADDR_ANY
		
			mov @timecount,0
		@@:
			invoke	connect,@hSocket,addr @stSin,sizeof @stSin
			.if	cmp <<eax ,SOCKET_ERROR>>,zero?
				invoke	WSAGetLastError
				.if <<cmp eax , WSAEWOULDBLOCK>>,nozero?
					inc @timecount
					invoke Sleep,100
					.if <<cmp @timecount,20>>,greater?
						;invoke  logout,addr  atext (_http_again_connect,"http_again_connect?"),sizeof  _http_again_connect
						mov eax,0
						jmp exit
					.else
						jmp @b
					.endif	
				.endif
			.endif
			mov rax,@hSocket
			add rsp,40h
			ret
		exit:	
			mov rax,0
			add rsp,40h
			ret
		
connect_server_with_ipv6 endp

connect_server_for_https proc	<:qword,:qword,:qword,qword,:qword,:qword> uses rbx rsi rdi r10 r11 r12 r13 r14 r15 _ipaddress_domain:qword,_TargetName:qword,_TargetName_wide:qword,_pCredHandle:qword,_pCtxtHandle:qword,_ptimstamp:qword
		LOCAL @stWsa:WSADATA
		LOCAL @stSin:sockaddr_in
		LOCAL @hSocket:qword
		LOCAL @hheap:qword
		LOCAL @SecPkgContext_StreamSizes_buffer	:SecPkgContext_StreamSizes
			mov _ipaddress_domain,rcx
			mov _TargetName,rdx
			mov _TargetName_wide,r8
			mov _pCredHandle,r9
			sub rsp,40h
		;	mov _preturn_hSocket,rcx
		
			invoke	WSAStartup,0202h,addr @stWsa
			invoke	socket,AF_INET,SOCK_STREAM,IPPROTO_TCP
			.if << cmp rax,INVALID_SOCKET>>,zero?
				invoke logout,addr atext (https_WSAStartup_error,"htttps_WSAStartup_error"),sizeof https_WSAStartup_error
				; invoke MessageBoxA,hWnd,addr errorsocket,addr errorsocket,MB_OK
				 mov rax,0
				jmp exit
			.endif
			mov	@hSocket,rax
			invoke _HostnameToIP,_ipaddress_domain
			.if	<<cmp eax ,INADDR_NONE>>,zero?;INADDR_NONE==-1
				invoke logout,addr atext (_https_inet_addr_error,"https_inet_addr_error"),sizeof _https_inet_addr_error
				mov rax,0
				jmp exit
			.endif
			mov	@stSin.sin_addr,eax
			mov	@stSin.sin_family,AF_INET
			mov eax,443
			invoke	htons,rax		;htonl()表示将32位的主机字节顺序转化为32位的网络字节顺序 htons()表示将16位的主机字节顺序转化为16位的网络字节顺序（ip地址是32位的端口号是16位的 ）
			mov	@stSin.sin_port,ax
		@@:
			invoke	connect,@hSocket,addr @stSin,sizeof @stSin
			.if	cmp <<eax ,SOCKET_ERROR>>,zero?
				invoke	WSAGetLastError
				.if <<cmp eax , WSAEWOULDBLOCK>>,nozero?
					invoke Sleep,1000
					invoke  logout,addr  atext (_https_again_connect,"https_again_connect?"),sizeof  _https_again_connect
					; invoke MessageBoxA,hWnd,addr again_connect,addr again_connect,MB_OKCANCEL;;"确定== 1"   "取消== 2"
					mov rax,0
					jmp exit
				.endif
			.endif
			invoke connect_SecurityContext,@hSocket,_TargetName,_TargetName_wide,_pCredHandle,_pCtxtHandle,_ptimstamp
			.if <<test rax,rax>>,zero?
				invoke logout,addr atext(error_SecurityContext,"connect_SecurityContext调用失败"),sizeof error_SecurityContext
				jmp exit
			.endif
			invoke QueryContextAttributesA,_pCtxtHandle,SECPKG_ATTR_STREAM_SIZES,addr @SecPkgContext_StreamSizes_buffer
			.if <<cmp rax,0>>,nozero?
				invoke  logout,addr atext(_QueryContextAttributes,"QueryContextAttributes调用失败"),sizeof _QueryContextAttributes
				mov rax,0
				jmp exit
			.endif
			mov eax,@SecPkgContext_StreamSizes_buffer.cbMaximumMessage
			.if <<cmp eax,0>>,zero?
				invoke  logout,addr atext(_cbMaximumMessage,"cbMaximumMessage为空值"),sizeof _cbMaximumMessage
				jmp exit
			.endif
			mov eax,@SecPkgContext_StreamSizes_buffer.cBuffers
			.if <<cmp eax,4>>,above?
				invoke  logout,addr atext(_StreamSizes_buffer_cBuffers,"没有加解密缓冲区"),sizeof _StreamSizes_buffer_cBuffers
				mov rax,0
				jmp exit
			.endif
			mov rax,@hSocket
			add rsp,40h
			ret
		exit:	
			
			mov rax,0
			add rsp,40h
			ret
			
connect_server_for_https endp

end
