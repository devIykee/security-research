contract Contract {
    function main() {
        memory[0x40:0x60] = 0x80;
    
        if (msg.data.length >= 0x04) {
            var var0 = msg.data[0x00:0x20] >> 0xe0;
        
            if (0x95d89b41 > var0) {
                if (0x6ac5eeee > var0) {
                    if (0x29dbecb1 > var0) {
                        if (var0 == 0x06fdde03) {
                            // Dispatch table entry for name()
                            var var1 = msg.value;
                        
                            if (var1) { revert(memory[0x00:0x00]); }
                        
                            var1 = 0x0208;
                            var1 = func_06EE();
                        
                        label_0208:
                            var temp0 = var1;
                            var1 = 0x0215;
                            var var2 = temp0;
                            var var3 = memory[0x40:0x60];
                            var1 = func_2291(var2, var3);
                        
                        label_0215:
                            var temp1 = memory[0x40:0x60];
                            return memory[temp1:temp1 + var1 - temp1];
                        } else if (var0 == 0x095ea7b3) {
                            // Dispatch table entry for approve(address,uint256)
                            var1 = msg.value;
                        
                            if (var1) { revert(memory[0x00:0x00]); }
                        
                            var1 = 0x023d;
                            var2 = 0x0238;
                            var3 = msg.data.length;
                            var var4 = 0x04;
                            var2, var3 = transfer(var3, var4);
                            var1 = func_0238(var2, var3);
                        
                        label_023D:
                            var temp2 = memory[0x40:0x60];
                            memory[temp2:temp2 + 0x20] = !!var1;
                            var1 = temp2 + 0x20;
                            goto label_0215;
                        } else if (var0 == 0x18160ddd) {
                            // Dispatch table entry for totalSupply()
                            var1 = msg.value;
                        
                            if (var1) { revert(memory[0x00:0x00]); }
                        
                            var temp3 = memory[0x40:0x60];
                            memory[temp3:temp3 + 0x20] = storage[0x02];
                            var1 = temp3 + 0x20;
                            goto label_0215;
                        } else if (var0 == 0x23b872dd) {
                            // Dispatch table entry for transferFrom(address,address,uint256)
                            var1 = msg.value;
                        
                            if (var1) { revert(memory[0x00:0x00]); }
                        
                            var1 = 0x023d;
                            var2 = 0x0285;
                            var3 = msg.data.length;
                            var4 = 0x04;
                            var2, var3, var4 = func_231B(var3, var4);
                            var var5 = 0x00;
                            var var6 = msg.sender;
                            var var7 = 0x07a4;
                            var var8 = var2;
                            var var9 = var6;
                            var var10 = var4;
                            func_13C1(var8, var9, var10);
                            var7 = 0x07af;
                            var8 = var2;
                            var9 = var3;
                            var10 = var4;
                        
                        label_1442:
                        
                            if (!(var8 & (0x01 << 0xa0) - 0x01)) {
                                var temp6 = memory[0x40:0x60];
                                memory[temp6:temp6 + 0x20] = 0x4b637e8f << 0xe1;
                                memory[temp6 + 0x04:temp6 + 0x04 + 0x20] = 0x00;
                                var11 = temp6 + 0x24;
                                goto label_1425;
                            } else if (var9 & (0x01 << 0xa0) - 0x01) {
                                var var11 = 0x13bc;
                                var var12 = var8;
                                var var13 = var9;
                                var var14 = var10;
                                func_1A12(var12, var13, var14);
                                // Error: Could not resolve jump destination!
                            } else {
                                var temp4 = memory[0x40:0x60];
                                memory[temp4:temp4 + 0x20] = 0xec442f05 << 0xe0;
                                memory[temp4 + 0x04:temp4 + 0x04 + 0x20] = 0x00;
                                var11 = temp4 + 0x24;
                            
                            label_1425:
                                var temp5 = memory[0x40:0x60];
                                revert(memory[temp5:temp5 + var11 - temp5]);
                            }
                        } else { revert(memory[0x00:0x00]); }
                    } else if (var0 == 0x29dbecb1) {
                        // Dispatch table entry for setMainPool(address)
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x02a9;
                        var2 = 0x02a4;
                        var3 = msg.data.length;
                        var4 = 0x04;
                        var2 = func_2359(var3, var4);
                    
                        if (msg.sender != storage[0x0b] & (0x01 << 0xa0) - 0x01) {
                            var temp17 = memory[0x40:0x60];
                            memory[temp17:temp17 + 0x20] = 0x0f46c81b << 0xe2;
                            var temp18 = memory[0x40:0x60];
                            revert(memory[temp18:temp18 + (temp17 + 0x04) - temp18]);
                        } else if (storage[0x0e] & (0x01 << 0xa0) - 0x01) {
                            var temp15 = memory[0x40:0x60];
                            memory[temp15:temp15 + 0x20] = 0x2fc00d1f << 0xe1;
                            var temp16 = memory[0x40:0x60];
                            revert(memory[temp16:temp16 + (temp15 + 0x04) - temp16]);
                        } else if (var2 & (0x01 << 0xa0) - 0x01) {
                            var3 = 0x00;
                            var4 = var2 & (0x01 << 0xa0) - 0x01;
                            var5 = 0x0dfe1681;
                            var temp7 = memory[0x40:0x60];
                            memory[temp7:temp7 + 0x20] = (var5 & 0xffffffff) << 0xe0;
                            var6 = temp7 + 0x04;
                            var temp8 = memory[0x40:0x60];
                            var temp9;
                            temp9, memory[temp8:temp8 + 0x20] = address(var4).staticcall.gas(msg.gas)(memory[temp8:temp8 + var6 - temp8]);
                            var7 = !temp9;
                        
                            if (!var7) {
                                var temp10 = memory[0x40:0x60];
                                var temp11 = returndata.length;
                                memory[0x40:0x60] = temp10 + (temp11 + 0x1f & ~0x1f);
                                var4 = 0x0899;
                                var5 = temp10 + temp11;
                                var6 = temp10;
                                var7 = 0x00;
                            
                                if (var5 - var6 i< 0x20) { revert(memory[0x00:0x00]); }
                            
                                var8 = memory[var6:var6 + 0x20];
                                var9 = 0x07b5;
                                var10 = var8;
                                func_22DD(var10);
                                var4 = var8;
                                // Error: Could not resolve jump destination!
                            } else {
                                var temp12 = returndata.length;
                                memory[0x00:0x00 + temp12] = returndata[0x00:0x00 + temp12];
                                revert(memory[0x00:0x00 + returndata.length]);
                            }
                        } else {
                            var temp13 = memory[0x40:0x60];
                            memory[temp13:temp13 + 0x20] = 0xd92e233d << 0xe0;
                            var temp14 = memory[0x40:0x60];
                            revert(memory[temp14:temp14 + (temp13 + 0x04) - temp14]);
                        }
                    } else if (var0 == 0x2c1f5216) {
                        // Dispatch table entry for dividendTracker()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x02ca;
                        var2 = storage[0x0d] & (0x01 << 0xa0) - 0x01;
                    
                    label_02CA:
                        var temp19 = memory[0x40:0x60];
                        memory[temp19:temp19 + 0x20] = var2 & (0x01 << 0xa0) - 0x01;
                        var2 = temp19 + 0x20;
                        goto label_0215;
                    } else if (var0 == 0x313ce567) {
                        // Dispatch table entry for decimals()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var temp20 = memory[0x40:0x60];
                        memory[temp20:temp20 + 0x20] = 0x12;
                        var1 = temp20 + 0x20;
                        goto label_0215;
                    } else if (var0 == 0x6425666b) {
                        // Dispatch table entry for portal()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x02ca;
                        var2 = storage[0x0b] & (0x01 << 0xa0) - 0x01;
                        goto label_02CA;
                    } else { revert(memory[0x00:0x00]); }
                } else if (0x79502c55 > var0) {
                    if (var0 == 0x6ac5eeee) {
                        // Dispatch table entry for swapBack()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x025d;
                        var2 = 0x00;
                        var3 = 0x09df;
                        func_14FD();
                        var3 = 0x09ea;
                        var4 = ~0x00;
                        var5 = 0x00;
                    
                    label_1518:
                        var6 = 0x00;
                    
                        if (storage[0x0e] / (0x01 << 0xa8) & 0xff) {
                            memory[0x00:0x20] = address(this);
                            memory[0x20:0x40] = 0x00;
                            var8 = 0x00;
                            var7 = storage[keccak256(memory[var8:var8 + 0x40])];
                            var9 = var8;
                            var10 = 0x155f;
                            var11 = var7;
                            var12 = var4;
                            var temp21 = storage[0x0e];
                            var temp22 = memory[0x40:0x60];
                            memory[temp22:temp22 + 0x20] = 0x3850c7bd << 0xe0;
                            var temp23 = memory[0x40:0x60];
                            var13 = 0x00;
                            var14 = var13;
                            var var15 = temp21 & (0x01 << 0xa0) - 0x01;
                            var var16 = temp21 / (0x01 << 0xa0) & 0xff;
                            var var17 = var14;
                            var var18 = var17;
                            var var19 = var18;
                            var var20 = var15;
                            var var21 = 0x3850c7bd;
                            var var22 = temp22 + 0x04;
                            var temp24;
                            temp24, memory[temp23:temp23 + 0xe0] = address(var20).staticcall.gas(msg.gas)(memory[temp23:temp23 + temp22 - temp23 + 0x04]);
                            var var23 = !temp24;
                        
                            if (!var23) {
                                var temp25 = memory[0x40:0x60];
                                var temp26 = returndata.length;
                                memory[0x40:0x60] = temp25 + (temp26 + 0x1f & ~0x1f);
                                var20 = 0x1c9b;
                                var21 = temp25 + temp26;
                                var22 = temp25;
                                var var24;
                                var var25;
                                var var26;
                                var20, var21, var22, var23, var24, var25, var26 = func_2597(var21, var22);
                                var temp27 = var20;
                                var19 = temp27;
                                var20 = 0x1cad;
                                var21 = var19;
                                var22 = var16;
                                var20 = func_173F(var21, var22);
                            
                                if (var11 >= var20) {
                                    var20 = 0x00;
                                    var21 = var15 & (0x01 << 0xa0) - 0x01;
                                    var22 = 0x1a686502;
                                    var temp28 = memory[0x40:0x60];
                                    memory[temp28:temp28 + 0x20] = (var22 & 0xffffffff) << 0xe0;
                                    var23 = temp28 + 0x04;
                                    var temp29 = memory[0x40:0x60];
                                    var temp30;
                                    temp30, memory[temp29:temp29 + 0x20] = address(var21).staticcall.gas(msg.gas)(memory[temp29:temp29 + var23 - temp29]);
                                    var24 = !temp30;
                                
                                    if (!var24) {
                                        var temp31 = memory[0x40:0x60];
                                        var temp32 = returndata.length;
                                        memory[0x40:0x60] = temp31 + (temp32 + 0x1f & ~0x1f);
                                        var21 = 0x1d2e;
                                        var23 = temp31;
                                        var22 = var23 + temp32;
                                        var21 = func_2AA6(var22, var23);
                                        var temp33 = var21;
                                        var20 = temp33;
                                        var21 = 0x00;
                                        var22 = 0x1d3c;
                                        var23 = var19;
                                        var24 = var20;
                                        var25 = var16;
                                        var22 = func_209C(var23, var24, var25);
                                        var21 = var22;
                                    
                                        if (var11 < var21) {
                                            var17 = var11;
                                        
                                            if (var12 >= var17) {
                                            label_1D5B:
                                            
                                                if (0x00 - var17) {
                                                label_1D7B:
                                                    var22 = 0x1d86;
                                                    var23 = var17;
                                                    var24 = var19;
                                                    var25 = var16;
                                                    var26 = 0x00;
                                                
                                                    if (!var25) {
                                                        var var27 = 0x219a;
                                                        var var28 = 0x2186;
                                                        var var29 = var23;
                                                        var var30 = 0x01 << 0x60;
                                                        var var31 = var24 & (0x01 << 0xa0) - 0x01;
                                                    
                                                    label_1F45:
                                                        var var32 = 0x00;
                                                        var var33 = var32;
                                                        var var34 = 0x00;
                                                        var var35 = 0x1f52;
                                                        var var36 = var29;
                                                        var var37 = var30;
                                                        var var38 = 0x00;
                                                        var var39 = var38;
                                                        var var40 = ~0x00;
                                                        var var41 = var37;
                                                        var var42 = var36;
                                                        // Unhandled termination
                                                    } else {
                                                        var27 = 0x2164;
                                                        var28 = 0x2150;
                                                        var29 = var23;
                                                        var30 = var24 & (0x01 << 0xa0) - 0x01;
                                                        var31 = 0x01 << 0x60;
                                                        goto label_1F45;
                                                    }
                                                } else {
                                                label_1D63:
                                                    var temp34 = memory[0x40:0x60];
                                                    memory[temp34:temp34 + 0x20] = 0x638ef2b1 << 0xe1;
                                                    var temp35 = memory[0x40:0x60];
                                                    revert(memory[temp35:temp35 + (temp34 + 0x04) - temp35]);
                                                }
                                            } else {
                                            label_1D58:
                                                var17 = var12;
                                            
                                                if (0x00 - var17) { goto label_1D7B; }
                                                else { goto label_1D63; }
                                            }
                                        } else {
                                            var22 = var21;
                                            var17 = var22;
                                        
                                            if (var12 >= var17) { goto label_1D5B; }
                                            else { goto label_1D58; }
                                        }
                                    } else {
                                        var temp36 = returndata.length;
                                        memory[0x00:0x00 + temp36] = returndata[0x00:0x00 + temp36];
                                        revert(memory[0x00:0x00 + returndata.length]);
                                    }
                                } else {
                                    var temp37 = memory[0x40:0x60];
                                    memory[temp37:temp37 + 0x20] = 0x51d41b59 << 0xe1;
                                    var temp38 = memory[0x40:0x60];
                                    revert(memory[temp38:temp38 + (temp37 + 0x04) - temp38]);
                                }
                            } else {
                                var temp39 = returndata.length;
                                memory[0x00:0x00 + temp39] = returndata[0x00:0x00 + temp39];
                                revert(memory[0x00:0x00 + returndata.length]);
                            }
                        } else {
                            var temp40 = memory[0x40:0x60];
                            memory[temp40:temp40 + 0x20] = 0x3c675863 << 0xe0;
                            var temp41 = memory[0x40:0x60];
                            revert(memory[temp41:temp41 + (temp40 + 0x04) - temp41]);
                        }
                    } else if (var0 == 0x6e1b6cda) {
                        // Dispatch table entry for swapBackThreshold()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x025d;
                        var1 = swapBackThreshold();
                    
                    label_025D:
                        var temp42 = memory[0x40:0x60];
                        memory[temp42:temp42 + 0x20] = var1;
                        var1 = temp42 + 0x20;
                        goto label_0215;
                    } else if (var0 == 0x70a08231) {
                        // Dispatch table entry for balanceOf(address)
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x025d;
                        var2 = 0x035e;
                        var3 = msg.data.length;
                        var4 = 0x04;
                        var2 = func_2359(var3, var4);
                        var1 = func_035E(var2);
                        goto label_025D;
                    } else if (var0 == 0x751f978c) {
                        // Dispatch table entry for swapBack(uint256,uint256)
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x025d;
                        var2 = 0x0392;
                        var3 = msg.data.length;
                        var4 = 0x04;
                        var2, var3 = func_2374(var3, var4);
                        var4 = 0x00;
                        var5 = 0x0ab2;
                        func_14FD();
                        var5 = 0x0abc;
                        var6 = var2;
                        var7 = var3;
                        goto label_1518;
                    } else { revert(memory[0x00:0x00]); }
                } else if (var0 == 0x79502c55) {
                    // Dispatch table entry for config()
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var temp43 = memory[0x40:0x60];
                    memory[0x40:0x60] = temp43 + 0x0100;
                    memory[temp43:temp43 + 0x20] = 0x00;
                    memory[temp43 + 0x20:temp43 + 0x20 + 0x20] = 0x00;
                    memory[temp43 + 0x40:temp43 + 0x40 + 0x20] = 0x00;
                    memory[temp43 + 0x60:temp43 + 0x60 + 0x20] = 0x00;
                    memory[temp43 + 0x80:temp43 + 0x80 + 0x20] = 0x00;
                    memory[temp43 + 0xa0:temp43 + 0xa0 + 0x20] = 0x00;
                    memory[temp43 + 0xc0:temp43 + 0xc0 + 0x20] = 0x00;
                    memory[temp43 + 0xe0:temp43 + 0xe0 + 0x20] = 0x00;
                    var temp44 = memory[0x40:0x60];
                    memory[0x40:0x60] = temp44 + 0x0100;
                    var temp45 = storage[0x08];
                    memory[temp44:temp44 + 0x20] = temp45 & 0xffff;
                    memory[temp44 + 0x20:temp44 + 0x20 + 0x20] = temp45 / 0x010000 & 0xffff;
                    memory[temp44 + 0x40:temp44 + 0x40 + 0x20] = temp45 / 0x0100000000 & 0xffff;
                    memory[temp44 + 0x60:temp44 + 0x60 + 0x20] = temp45 / 0x01000000000000 & 0xffff;
                    memory[temp44 + 0x80:temp44 + 0x80 + 0x20] = temp45 / 0x010000000000000000 & 0xffff;
                    memory[temp44 + 0xa0:temp44 + 0xa0 + 0x20] = temp45 / (0x01 << 0x50) & (0x01 << 0xa0) - 0x01;
                    var temp46 = storage[0x09];
                    memory[temp44 + 0xc0:temp44 + 0xc0 + 0x20] = temp46 & 0xffffffff;
                    memory[temp44 + 0xe0:temp44 + 0xe0 + 0x20] = temp46 / 0x0100000000 & (0x01 << 0x60) - 0x01;
                    var1 = temp44;
                    var temp47 = var1;
                    var1 = 0x0215;
                    var2 = temp47;
                    var3 = memory[0x40:0x60];
                    var1 = config(var2, var3);
                    goto label_0215;
                } else if (var0 == 0x7c294c4c) {
                    // Dispatch table entry for 0x7c294c4c (unknown)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x02a9;
                    var2 = 0x049f;
                    var3 = msg.data.length;
                    var4 = 0x04;
                    var2 = func_2421(var3, var4);
                
                    if (!(storage[0x0e] / (0x01 << 0xb0) & 0xff)) {
                        storage[0x0e] = (storage[0x0e] & ~(0xff << 0xb0)) | (0x01 << 0xb0);
                        var temp48 = var2;
                        var3 = temp48 + 0x0140;
                        var4 = 0x03e8;
                        var5 = 0x0b27;
                        var6 = temp48 + 0x0160;
                        var7 = var3;
                        var5 = func_263D(var6, var7);
                        var4 = var5 & 0xffff > var4;
                    
                        if (var4) {
                        label_0B4B:
                        
                            if (!var4) {
                                var4 = 0x0b79;
                                var temp49 = var3;
                                var5 = temp49 + 0x40;
                                var6 = temp49 + 0x20;
                                var4 = func_263D(var5, var6);
                                var5 = 0x0b86;
                                var6 = var3 + 0x20;
                                var7 = var3;
                                var5 = func_263D(var6, var7);
                                var temp50 = var4;
                                var4 = 0x0b90;
                                var temp51 = var5;
                                var5 = temp50;
                                var6 = temp51;
                                var4 = func_266C(var5, var6);
                            
                                if (0x00 - (var4 & 0xffff)) {
                                    var4 = 0x2710;
                                    var5 = 0x0bc6;
                                    var temp52 = var3;
                                    var6 = temp52 + 0xa0;
                                    var7 = temp52 + 0x80;
                                    var5 = func_263D(var6, var7);
                                    var5 = var5 & 0xffff;
                                    var6 = 0x0bda;
                                    var temp53 = var3;
                                    var7 = temp53 + 0x80;
                                    var8 = temp53 + 0x60;
                                    var6 = func_263D(var7, var8);
                                    var6 = var6 & 0xffff;
                                    var7 = 0x0bee;
                                    var temp54 = var3;
                                    var8 = temp54 + 0x60;
                                    var9 = temp54 + 0x40;
                                    var7 = func_263D(var8, var9);
                                    var temp55 = var6;
                                    var6 = 0x0bfc;
                                    var8 = var7 & 0xffff;
                                    var7 = temp55;
                                    var6 = func_2687(var7, var8);
                                    var temp56 = var5;
                                    var5 = 0x0c06;
                                    var temp57 = var6;
                                    var6 = temp56;
                                    var7 = temp57;
                                    var5 = func_2687(var6, var7);
                                
                                    if (var5 == var4) {
                                        var4 = 0x00;
                                        var5 = 0x0c35;
                                        var temp58 = var3;
                                        var6 = temp58 + 0x60;
                                        var7 = temp58 + 0x40;
                                        var5 = func_263D(var6, var7);
                                        var temp59 = var5 & 0xffff > var4;
                                        var4 = temp59;
                                    
                                        if (!var4) {
                                        label_0C5D:
                                        
                                            if (!var4) {
                                                var4 = 0x00;
                                                var5 = 0x0c8c;
                                                var temp60 = var2;
                                                var6 = temp60 + 0xe0;
                                                var7 = temp60 + 0xc0;
                                                var5 = func_2359(var6, var7);
                                                var4 = var5 & (0x01 << 0xa0) - 0x01 == var4;
                                            
                                                if (var4) {
                                                label_0CB9:
                                                
                                                    if (var4) {
                                                    label_0CDB:
                                                    
                                                        if (var4) {
                                                            if (!var4) {
                                                            label_0D06:
                                                                var4 = 0x00;
                                                                var5 = 0x0d17;
                                                                var temp61 = var3;
                                                                var6 = temp61 + 0xa0;
                                                                var7 = temp61 + 0x80;
                                                                var5 = func_263D(var6, var7);
                                                                var temp62 = var5 & 0xffff > var4;
                                                                var4 = temp62;
                                                            
                                                                if (!var4) {
                                                                label_0D41:
                                                                
                                                                    if (!var4) {
                                                                        var4 = 0x0d69;
                                                                        var5 = var2;
                                                                        var6 = var5;
                                                                        var4, var5 = func_269A(var5, var6);
                                                                        var temp63 = var4;
                                                                        var4 = 0x05;
                                                                        var temp64 = var5;
                                                                        var5 = 0x0d77;
                                                                        var6 = temp64;
                                                                        var7 = temp63;
                                                                        var8 = var4;
                                                                        func_273C(var6, var7, var8);
                                                                        var4 = 0x0d85;
                                                                        var5 = var2 + 0x20;
                                                                        var6 = var2;
                                                                        var4, var5 = func_269A(var5, var6);
                                                                        var temp65 = var4;
                                                                        var4 = 0x06;
                                                                        var temp66 = var5;
                                                                        var5 = 0x0d93;
                                                                        var6 = temp66;
                                                                        var7 = temp65;
                                                                        var8 = var4;
                                                                        func_273C(var6, var7, var8);
                                                                        var4 = 0x0da1;
                                                                        var5 = var2 + 0x40;
                                                                        var6 = var2;
                                                                        var4, var5 = func_269A(var5, var6);
                                                                        var temp67 = var4;
                                                                        var4 = 0x07;
                                                                        var temp68 = var5;
                                                                        var5 = 0x0daf;
                                                                        var6 = temp68;
                                                                        var7 = temp67;
                                                                        var8 = var4;
                                                                        func_273C(var6, var7, var8);
                                                                        var4 = var3;
                                                                        var5 = 0x08;
                                                                        var6 = 0x0dbd;
                                                                        var7 = var4;
                                                                        var8 = var5;
                                                                        var9 = msg.data[var7:var7 + 0x20];
                                                                        var10 = 0x284d;
                                                                        var11 = var9;
                                                                        func_2490(var11);
                                                                        var temp69 = var9 & 0xffff;
                                                                        var9 = temp69;
                                                                        var temp70 = var8;
                                                                        var10 = storage[temp70];
                                                                        storage[temp70] = (var10 & ~0xffff) | var9;
                                                                        var11 = msg.data[var7 + 0x20:var7 + 0x20 + 0x20];
                                                                        var12 = 0x286e;
                                                                        var13 = var11;
                                                                        func_2490(var13);
                                                                        storage[var8] = (var10 & ~0xffffffff) | var9 | ((var11 << 0x10) & 0xffff0000);
                                                                        var9 = 0x28b5;
                                                                        var10 = 0x2897;
                                                                        var11 = var7 + 0x40;
                                                                        var12 = 0x00;
                                                                        var13 = msg.data[var11:var11 + 0x20];
                                                                        var14 = 0x0791;
                                                                        var15 = var13;
                                                                        func_2490(var15);
                                                                        var10 = var13;
                                                                        // Error: Could not resolve jump destination!
                                                                    } else {
                                                                        var temp71 = memory[0x40:0x60];
                                                                        memory[temp71:temp71 + 0x20] = 0xd92e233d << 0xe0;
                                                                        var temp72 = memory[0x40:0x60];
                                                                        revert(memory[temp72:temp72 + (temp71 + 0x04) - temp72]);
                                                                    }
                                                                } else {
                                                                    var4 = 0x00;
                                                                    var5 = 0x0d36;
                                                                    var temp73 = var2;
                                                                    var6 = temp73 + 0x0120;
                                                                    var7 = temp73 + 0x0100;
                                                                    var5 = func_2359(var6, var7);
                                                                    var4 = var5 & (0x01 << 0xa0) - 0x01 == var4;
                                                                    goto label_0D41;
                                                                }
                                                            } else {
                                                            label_0CEE:
                                                                var temp74 = memory[0x40:0x60];
                                                                memory[temp74:temp74 + 0x20] = 0xd92e233d << 0xe0;
                                                                var temp75 = memory[0x40:0x60];
                                                                revert(memory[temp75:temp75 + (temp74 + 0x04) - temp75]);
                                                            }
                                                        } else if (msg.data[var2 + 0x60:var2 + 0x60 + 0x20]) { goto label_0D06; }
                                                        else { goto label_0CEE; }
                                                    } else {
                                                        var4 = 0x00;
                                                        var5 = 0x0cd0;
                                                        var temp76 = var2;
                                                        var6 = temp76 + 0xa0;
                                                        var7 = temp76 + 0x80;
                                                        var5 = func_2359(var6, var7);
                                                        var4 = var5 & (0x01 << 0xa0) - 0x01 == var4;
                                                        goto label_0CDB;
                                                    }
                                                } else {
                                                    var4 = 0x00;
                                                    var5 = 0x0cae;
                                                    var temp77 = var2;
                                                    var6 = temp77 + 0x0100;
                                                    var7 = temp77 + 0xe0;
                                                    var5 = func_2359(var6, var7);
                                                    var4 = var5 & (0x01 << 0xa0) - 0x01 == var4;
                                                    goto label_0CB9;
                                                }
                                            } else {
                                                var temp78 = memory[0x40:0x60];
                                                memory[temp78:temp78 + 0x20] = 0xd53b86bd << 0xe0;
                                                var temp79 = memory[0x40:0x60];
                                                revert(memory[temp79:temp79 + (temp78 + 0x04) - temp79]);
                                            }
                                        } else {
                                            var4 = 0x00;
                                            var5 = 0x0c52;
                                            var temp80 = var3;
                                            var6 = temp80 + 0xc0;
                                            var7 = temp80 + 0xa0;
                                            var5 = func_2359(var6, var7);
                                            var4 = var5 & (0x01 << 0xa0) - 0x01 == var4;
                                            goto label_0C5D;
                                        }
                                    } else {
                                        var temp81 = memory[0x40:0x60];
                                        memory[temp81:temp81 + 0x20] = 0x9eaf1ad1 << 0xe0;
                                        var temp82 = memory[0x40:0x60];
                                        revert(memory[temp82:temp82 + (temp81 + 0x04) - temp82]);
                                    }
                                } else {
                                    var temp83 = memory[0x40:0x60];
                                    memory[temp83:temp83 + 0x20] = 0x2e5e6d7d << 0xe1;
                                    var temp84 = memory[0x40:0x60];
                                    revert(memory[temp84:temp84 + (temp83 + 0x04) - temp84]);
                                }
                            } else {
                                var temp85 = memory[0x40:0x60];
                                memory[temp85:temp85 + 0x20] = 0x2bc7b84d << 0xe2;
                                var temp86 = memory[0x40:0x60];
                                revert(memory[temp86:temp86 + (temp85 + 0x04) - temp86]);
                            }
                        } else {
                            var4 = 0x03e8;
                            var5 = 0x0b45;
                            var temp87 = var3;
                            var6 = temp87 + 0x40;
                            var7 = temp87 + 0x20;
                            var5 = func_263D(var6, var7);
                            var4 = var5 & 0xffff > var4;
                            goto label_0B4B;
                        }
                    } else {
                        var temp88 = memory[0x40:0x60];
                        memory[temp88:temp88 + 0x20] = 0xdc149f << 0xe4;
                        var temp89 = memory[0x40:0x60];
                        revert(memory[temp89:temp89 + (temp88 + 0x04) - temp89]);
                    }
                } else if (var0 == 0x856bfdb8) {
                    // Dispatch table entry for 0x856bfdb8 (unknown)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x023d;
                    var2 = storage[0x0e] / (0x01 << 0xa0) & 0xff;
                    goto label_023D;
                } else if (var0 == 0x8da5cb5b) {
                    // Dispatch table entry for owner()
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x02ca;
                    var2 = storage[0x0a] & (0x01 << 0xa0) - 0x01;
                    goto label_02CA;
                } else { revert(memory[0x00:0x00]); }
            } else if (0xdd62ed3e > var0) {
                if (0xad5dff73 > var0) {
                    if (var0 == 0x95d89b41) {
                        // Dispatch table entry for symbol()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x0208;
                        var1 = symbol();
                        goto label_0208;
                    } else if (var0 == 0x9963b6a4) {
                        // Dispatch table entry for 0x9963b6a4 (unknown)
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x025d;
                        var2 = storage[0x0f];
                        goto label_025D;
                    } else if (var0 == 0xa5a302d3) {
                        // Dispatch table entry for mainPool()
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x02ca;
                        var2 = storage[0x0e] & (0x01 << 0xa0) - 0x01;
                        goto label_02CA;
                    } else if (var0 == 0xa9059cbb) {
                        // Dispatch table entry for transfer(address,uint256)
                        var1 = msg.value;
                    
                        if (var1) { revert(memory[0x00:0x00]); }
                    
                        var1 = 0x023d;
                        var2 = 0x0545;
                        var3 = msg.data.length;
                        var4 = 0x04;
                        var2, var3 = transfer(var3, var4);
                        var4 = 0x00;
                        var5 = msg.sender;
                        var6 = 0x078b;
                        var7 = var5;
                        var8 = var2;
                        var9 = var3;
                        goto label_1442;
                    } else { revert(memory[0x00:0x00]); }
                } else if (var0 == 0xad5dff73) {
                    // Dispatch table entry for isExempt(address)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x023d;
                    var2 = 0x0564;
                    var3 = msg.data.length;
                    var4 = 0x04;
                    var2 = func_2359(var3, var4);
                    var2 = func_0564(var2);
                    goto label_023D;
                } else if (var0 == 0xb15be2f5) {
                    // Dispatch table entry for renounce()
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x02a9;
                    renounce();
                    stop();
                } else if (var0 == 0xbf56b371) {
                    // Dispatch table entry for launchedAt()
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x025d;
                    var2 = storage[0x10];
                    goto label_025D;
                } else if (var0 == 0xd3618cca) {
                    // Dispatch table entry for 0xd3618cca (unknown)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x02a9;
                    func_1169();
                    stop();
                } else { revert(memory[0x00:0x00]); }
            } else if (0xf3635019 > var0) {
                if (var0 == 0xdd62ed3e) {
                    // Dispatch table entry for allowance(address,address)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x025d;
                    var2 = 0x05cf;
                    var3 = msg.data.length;
                    var4 = 0x04;
                    var2, var3 = func_2459(var3, var4);
                    var1 = func_05CF(var2, var3);
                    goto label_025D;
                } else if (var0 == 0xe7c2b772) {
                    // Dispatch table entry for 0xe7c2b772 (unknown)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x023d;
                    var2 = storage[0x0e] / (0x01 << 0xa8) & 0xff;
                    goto label_023D;
                } else if (var0 == 0xeb1e7387) {
                    // Dispatch table entry for currentTaxes()
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x062d;
                    var1, var2 = currentTaxes();
                    var temp90 = memory[0x40:0x60];
                    memory[temp90:temp90 + 0x20] = var1 & 0xffff;
                    memory[temp90 + 0x20:temp90 + 0x20 + 0x20] = var2 & 0xffff;
                    var1 = temp90 + 0x40;
                    goto label_0215;
                } else if (var0 == 0xf2865b43) {
                    // Dispatch table entry for 0xf2865b43 (unknown)
                    var1 = msg.value;
                
                    if (var1) { revert(memory[0x00:0x00]); }
                
                    var1 = 0x02a9;
                    var2 = 0x0662;
                    var3 = msg.data.length;
                    var4 = 0x04;
                    var2, var3 = func_249F(var3, var4);
                    func_0662(var2, var3);
                    stop();
                } else { revert(memory[0x00:0x00]); }
            } else if (var0 == 0xf3635019) {
                // Dispatch table entry for 0xf3635019 (unknown)
                var1 = msg.value;
            
                if (var1) { revert(memory[0x00:0x00]); }
            
                var1 = 0x02ca;
                var2 = storage[0x0c] & (0x01 << 0xa0) - 0x01;
                goto label_02CA;
            } else if (var0 == 0xf972095a) {
                // Dispatch table entry for 0xf972095a (unknown)
                var1 = msg.value;
            
                if (var1) { revert(memory[0x00:0x00]); }
            
                var1 = 0x025d;
                var2 = storage[0x11];
                goto label_025D;
            } else if (var0 == 0xf9c0a3c3) {
                // Dispatch table entry for 0xf9c0a3c3 (unknown)
                var1 = msg.value;
            
                if (var1) { revert(memory[0x00:0x00]); }
            
                memory[0x00:0x20] = address(this);
                memory[0x20:0x40] = 0x00;
                var1 = storage[keccak256(memory[0x00:0x40])];
                goto label_025D;
            } else if (var0 == 0xfa461e33) {
                // Dispatch table entry for uniswapV3SwapCallback(int256,int256,bytes)
                var1 = msg.value;
            
                if (var1) { revert(memory[0x00:0x00]); }
            
                var1 = 0x02a9;
                var2 = 0x06d5;
                var3 = msg.data.length;
                var4 = 0x04;
                var2, var3, var4, var5 = func_24CB(var3, var4);
                func_06D5(var2, var3, var4, var5);
                stop();
            } else if (var0 == 0xfb7f21eb) {
                // Dispatch table entry for logo()
                var1 = msg.value;
            
                if (var1) { revert(memory[0x00:0x00]); }
            
                var1 = 0x0208;
                var1 = logo();
                goto label_0208;
            } else { revert(memory[0x00:0x00]); }
        } else if (msg.data.length) { revert(memory[0x00:0x00]); }
        else { stop(); }
    }
    
    function func_0238(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
        var var1 = msg.sender;
        var var2 = 0x078b;
        var var3 = var1;
        var var4 = arg0;
        var var5 = arg1;
        func_13AF(var3, var4, var5);
        return 0x01;
    }
    
    function func_035E(var arg0) returns (var r0) {
        memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
        memory[0x20:0x40] = 0x00;
        return storage[keccak256(memory[0x00:0x40])];
    }
    
    function func_0564(var arg0) returns (var arg0) {
        memory[0x20:0x40] = 0x12;
        memory[0x00:0x20] = arg0;
        return storage[keccak256(memory[0x00:0x40])] & 0xff;
    }
    
    function func_05CF(var arg0, var arg1) returns (var r0) {
        var temp0 = (0x01 << 0xa0) - 0x01;
        memory[0x00:0x20] = temp0 & arg0;
        memory[0x20:0x40] = 0x01;
        var temp1 = keccak256(memory[0x00:0x40]);
        memory[0x00:0x20] = temp0 & arg1;
        memory[0x20:0x40] = temp1;
        return storage[keccak256(memory[0x00:0x40])];
    }
    
    function func_0662(var arg0, var arg1) {
        if (msg.sender == storage[0x0a] & (0x01 << 0xa0) - 0x01) {
            var var0 = 0x08;
            var var1 = arg0 & 0xffff > storage[var0] & 0xffff;
        
            if (var1) {
                if (!var1) {
                label_12BA:
                    var temp0 = var0;
                    var temp1 = arg0 & 0xffff;
                    var temp2 = arg1 & 0xffff;
                    storage[temp0] = temp2 * 0x010000 | temp1 | (storage[temp0] & ~0xffffffff);
                    var temp3 = memory[0x40:0x60];
                    memory[temp3:temp3 + 0x20] = temp1;
                    memory[temp3 + 0x20:temp3 + 0x20 + 0x20] = temp2;
                    var temp4 = memory[0x40:0x60];
                    log(memory[temp4:temp4 + (temp3 + 0x40) - temp4], [0x7ee34b1eff0d151005ea4e57083c40b73b00c292337251a702b03d07368144fd]);
                    return;
                } else {
                label_12A2:
                    var temp5 = memory[0x40:0x60];
                    memory[temp5:temp5 + 0x20] = 0x1d63b067 << 0xe2;
                    var temp6 = memory[0x40:0x60];
                    revert(memory[temp6:temp6 + (temp5 + 0x04) - temp6]);
                }
            } else if (arg1 & 0xffff <= storage[var0] / 0x010000 & 0xffff) { goto label_12BA; }
            else { goto label_12A2; }
        } else {
            var temp7 = memory[0x40:0x60];
            memory[temp7:temp7 + 0x20] = 0x5fc483c5 << 0xe0;
            var temp8 = memory[0x40:0x60];
            revert(memory[temp8:temp8 + (temp7 + 0x04) - temp8]);
        }
    }
    
    function func_06D5(var arg0, var arg1, var arg2, var arg3) {
        var var0 = msg.sender != storage[0x13] & (0x01 << 0xa0) - 0x01;
    
        if (var0) {
            if (!var0) {
            label_135A:
                var0 = 0x00;
            
                if (arg0 i> var0) {
                    var0 = arg0;
                
                    if (var0 i> 0x00) {
                    label_138C:
                        var var1 = var0;
                        var var2 = 0x1398;
                        var var3 = address(this);
                        var var4 = msg.sender;
                        var var5 = var1;
                        func_181A(var3, var4, var5);
                        return;
                    } else {
                    label_1374:
                        var temp0 = memory[0x40:0x60];
                        memory[temp0:temp0 + 0x20] = 0xdab1e993 << 0xe0;
                        var temp1 = memory[0x40:0x60];
                        revert(memory[temp1:temp1 + (temp0 + 0x04) - temp1]);
                    }
                } else {
                    var1 = arg1;
                    var0 = var1;
                
                    if (var0 i> 0x00) { goto label_138C; }
                    else { goto label_1374; }
                }
            } else {
            label_1342:
                var temp2 = memory[0x40:0x60];
                memory[temp2:temp2 + 0x20] = 0xdab1e993 << 0xe0;
                var temp3 = memory[0x40:0x60];
                revert(memory[temp3:temp3 + (temp2 + 0x04) - temp3]);
            }
        } else if (storage[0x13] & (0x01 << 0xa0) - 0x01) { goto label_135A; }
        else { goto label_1342; }
    }
    
    function func_06EE() returns (var r0) {
        var var0 = 0x60;
        var var1 = 0x05;
        var var2 = 0x06fd;
        var var3 = storage[var1];
        var2 = func_2544(var3);
        var temp0 = var2;
        var temp1 = memory[0x40:0x60];
        memory[0x40:0x60] = temp1 + (temp0 + 0x1f) / 0x20 * 0x20 + 0x20;
        var temp2 = var1;
        var1 = temp1;
        var2 = temp2;
        var3 = temp0;
        memory[var1:var1 + 0x20] = var3;
        var var4 = var1 + 0x20;
        var var5 = var2;
        var var7 = storage[var5];
        var var6 = 0x0729;
        var6 = func_2544(var7);
    
        if (!var6) {
        label_0774:
            return var1;
        } else if (0x1f < var6) {
            var temp3 = var4;
            var temp4 = temp3 + var6;
            var4 = temp4;
            memory[0x00:0x20] = var5;
            var temp5 = keccak256(memory[0x00:0x20]);
            memory[temp3:temp3 + 0x20] = storage[temp5];
            var5 = temp5 + 0x01;
            var6 = temp3 + 0x20;
        
            if (var4 <= var6) { goto label_076B; }
        
        label_0757:
            var temp6 = var5;
            var temp7 = var6;
            memory[temp7:temp7 + 0x20] = storage[temp6];
            var5 = temp6 + 0x01;
            var6 = temp7 + 0x20;
        
            if (var4 > var6) { goto label_0757; }
        
        label_076B:
            var temp8 = var4;
            var temp9 = temp8 + (var6 - temp8 & 0x1f);
            var6 = temp8;
            var4 = temp9;
            goto label_0774;
        } else {
            var temp10 = var4;
            memory[temp10:temp10 + 0x20] = storage[var5] / 0x0100 * 0x0100;
            var4 = temp10 + 0x20;
            var6 = var6;
            goto label_0774;
        }
    }
    
    function swapBackThreshold() returns (var r0) {
        var var0 = 0x00;
        var var1 = storage[0x0e] & (0x01 << 0xa0) - 0x01;
    
        if (!var1) { return ~0x00; }
    
        var var2 = 0x00;
        var var3 = var1 & (0x01 << 0xa0) - 0x01;
        var var4 = 0x3850c7bd;
        var temp0 = memory[0x40:0x60];
        memory[temp0:temp0 + 0x20] = (var4 & 0xffffffff) << 0xe0;
        var var5 = temp0 + 0x04;
        var temp1 = memory[0x40:0x60];
        var temp2;
        temp2, memory[temp1:temp1 + 0xe0] = address(var3).staticcall.gas(msg.gas)(memory[temp1:temp1 + var5 - temp1]);
        var var6 = !temp2;
    
        if (!var6) {
            var temp3 = memory[0x40:0x60];
            var temp4 = returndata.length;
            memory[0x40:0x60] = temp3 + (temp4 + 0x1f & ~0x1f);
            var3 = 0x0a81;
            var5 = temp3;
            var4 = var5 + temp4;
            var var7;
            var var8;
            var var9;
            var3, var4, var5, var6, var7, var8, var9 = func_2597(var4, var5);
            var temp5 = var3;
            var2 = temp5;
            var3 = 0x0aa2;
            var4 = var2;
            var5 = storage[0x0e] / 0x0100 ** 0x14 & 0xff;
            return func_173F(var4, var5);
        } else {
            var temp6 = returndata.length;
            memory[0x00:0x00 + temp6] = returndata[0x00:0x00 + temp6];
            revert(memory[0x00:0x00 + returndata.length]);
        }
    }
    
    function symbol() returns (var r0) {
        var var0 = 0x60;
        var var1 = 0x06;
        var var2 = 0x06fd;
        var var3 = storage[var1];
        var2 = func_2544(var3);
        var temp0 = var2;
        var temp1 = memory[0x40:0x60];
        memory[0x40:0x60] = temp1 + (temp0 + 0x1f) / 0x20 * 0x20 + 0x20;
        var temp2 = var1;
        var1 = temp1;
        var2 = temp2;
        var3 = temp0;
        memory[var1:var1 + 0x20] = var3;
        var var4 = var1 + 0x20;
        var var5 = var2;
        var var7 = storage[var5];
        var var6 = 0x0729;
        var6 = func_2544(var7);
    
        if (!var6) {
        label_0774:
            return var1;
        } else if (0x1f < var6) {
            var temp3 = var4;
            var temp4 = temp3 + var6;
            var4 = temp4;
            memory[0x00:0x20] = var5;
            var temp5 = keccak256(memory[0x00:0x20]);
            memory[temp3:temp3 + 0x20] = storage[temp5];
            var5 = temp5 + 0x01;
            var6 = temp3 + 0x20;
        
            if (var4 <= var6) { goto label_076B; }
        
        label_0757:
            var temp6 = var5;
            var temp7 = var6;
            memory[temp7:temp7 + 0x20] = storage[temp6];
            var5 = temp6 + 0x01;
            var6 = temp7 + 0x20;
        
            if (var4 > var6) { goto label_0757; }
        
        label_076B:
            var temp8 = var4;
            var temp9 = temp8 + (var6 - temp8 & 0x1f);
            var6 = temp8;
            var4 = temp9;
            goto label_0774;
        } else {
            var temp10 = var4;
            memory[temp10:temp10 + 0x20] = storage[var5] / 0x0100 * 0x0100;
            var4 = temp10 + 0x20;
            var6 = var6;
            goto label_0774;
        }
    }
    
    function renounce() {
        if (msg.sender == storage[0x0a] & (0x01 << 0xa0) - 0x01) {
            log(memory[memory[0x40:0x60]:memory[0x40:0x60] + 0x00], [0xf8df31144d9c2f0f6b59d69b8b98abd5459d07f2742c4df920b25aae33c64820, storage[0x0a] & (0x01 << 0xa0) - 0x01]);
            storage[0x0a] = storage[0x0a] & ~((0x01 << 0xa0) - 0x01);
            return;
        } else {
            var temp0 = memory[0x40:0x60];
            memory[temp0:temp0 + 0x20] = 0x5fc483c5 << 0xe0;
            var temp1 = memory[0x40:0x60];
            revert(memory[temp1:temp1 + (temp0 + 0x04) - temp1]);
        }
    }
    
    function func_1169() {
        if (msg.sender != storage[0x0b] & (0x01 << 0xa0) - 0x01) {
            var temp3 = memory[0x40:0x60];
            memory[temp3:temp3 + 0x20] = 0x0f46c81b << 0xe2;
            var temp4 = memory[0x40:0x60];
            revert(memory[temp4:temp4 + (temp3 + 0x04) - temp4]);
        } else if (storage[0x0e] & (0x01 << 0xa0) - 0x01) {
            var temp0 = storage[0x0e];
            storage[0x0e] = (temp0 & ~(0xff << 0xa8)) | (0x01 << 0xa8);
            log(memory[memory[0x40:0x60]:memory[0x40:0x60] + 0x00], [0xc5ca2014458d93c5cf9f836ff7ece45de01c929dfb16eed9d6c3329fa1fd0982, storage[0x0e] & (0x01 << 0xa0) - 0x01]);
            var var0 = 0x120e;
            func_149F();
            return;
        } else {
            var temp1 = memory[0x40:0x60];
            memory[temp1:temp1 + 0x20] = 0x3c675863 << 0xe0;
            var temp2 = memory[0x40:0x60];
            revert(memory[temp2:temp2 + (temp1 + 0x04) - temp2]);
        }
    }
    
    function currentTaxes() returns (var r0, var r1) {
        r1 = 0x00;
        var var1 = r1;
        var var2 = storage[0x0f] != 0x00;
    
        if (!var2) {
            if (!var2) {
            label_1233:
                var temp0 = storage[0x08];
                r0 = temp0 & 0xffff;
                r1 = temp0 / 0x010000 & 0xffff;
                return r0, r1;
            } else {
            label_122C:
                r0 = 0x00;
                r1 = r0;
                return r0, r1;
            }
        } else if (block.timestamp < storage[0x0f]) { goto label_1233; }
        else { goto label_122C; }
    }
    
    function logo() returns (var r0) {
        var var0 = 0x60;
        var var1 = 0x07;
        var var2 = 0x06fd;
        var var3 = storage[var1];
        var2 = func_2544(var3);
        var temp0 = var2;
        var temp1 = memory[0x40:0x60];
        memory[0x40:0x60] = temp1 + (temp0 + 0x1f) / 0x20 * 0x20 + 0x20;
        var temp2 = var1;
        var1 = temp1;
        var2 = temp2;
        var3 = temp0;
        memory[var1:var1 + 0x20] = var3;
        var var4 = var1 + 0x20;
        var var5 = var2;
        var var7 = storage[var5];
        var var6 = 0x0729;
        var6 = func_2544(var7);
    
        if (!var6) {
        label_0774:
            return var1;
        } else if (0x1f < var6) {
            var temp3 = var4;
            var temp4 = temp3 + var6;
            var4 = temp4;
            memory[0x00:0x20] = var5;
            var temp5 = keccak256(memory[0x00:0x20]);
            memory[temp3:temp3 + 0x20] = storage[temp5];
            var5 = temp5 + 0x01;
            var6 = temp3 + 0x20;
        
            if (var4 <= var6) { goto label_076B; }
        
        label_0757:
            var temp6 = var5;
            var temp7 = var6;
            memory[temp7:temp7 + 0x20] = storage[temp6];
            var5 = temp6 + 0x01;
            var6 = temp7 + 0x20;
        
            if (var4 > var6) { goto label_0757; }
        
        label_076B:
            var temp8 = var4;
            var temp9 = temp8 + (var6 - temp8 & 0x1f);
            var6 = temp8;
            var4 = temp9;
            goto label_0774;
        } else {
            var temp10 = var4;
            memory[temp10:temp10 + 0x20] = storage[var5] / 0x0100 * 0x0100;
            var4 = temp10 + 0x20;
            var6 = var6;
            goto label_0774;
        }
    }
    
    function func_13AF(var arg0, var arg1, var arg2) {
        var var0 = 0x13bc;
        var var1 = arg0;
        var var2 = arg1;
        var var3 = arg2;
        var var4 = 0x01;
        func_1940(var1, var2, var3, var4);
    }
    
    function func_13C1(var arg0, var arg1, var arg2) {
        var temp0 = (0x01 << 0xa0) - 0x01;
        memory[0x00:0x20] = temp0 & arg0;
        memory[0x20:0x40] = 0x01;
        var temp1 = keccak256(memory[0x00:0x40]);
        memory[0x00:0x20] = arg1 & temp0;
        memory[0x20:0x40] = temp1;
        var var0 = storage[keccak256(memory[0x00:0x40])];
    
        if (var0 >= ~0x00) {
        label_143C:
            return;
        } else if (var0 >= arg2) {
            var var1 = 0x143c;
            var var2 = arg0;
            var var3 = arg1;
            var var4 = var0 - arg2;
            var var5 = 0x00;
            func_1940(var2, var3, var4, var5);
            goto label_143C;
        } else {
            var temp2 = memory[0x40:0x60];
            memory[temp2:temp2 + 0x20] = 0x7dc7a0d9 << 0xe1;
            memory[temp2 + 0x04:temp2 + 0x04 + 0x20] = arg1 & (0x01 << 0xa0) - 0x01;
            memory[temp2 + 0x24:temp2 + 0x24 + 0x20] = var0;
            memory[temp2 + 0x44:temp2 + 0x44 + 0x20] = arg2;
            var1 = temp2 + 0x64;
            var temp3 = memory[0x40:0x60];
            revert(memory[temp3:temp3 + var1 - temp3]);
        }
    }
    
    function func_149F() {
        var var0 = storage[0x0d] & (0x01 << 0xa0) - 0x01;
    
        if (!var0) { return; }
    
        var var1 = var0 & (0x01 << 0xa0) - 0x01;
        var var2 = 0xad7e01be;
        var temp0 = memory[0x40:0x60];
        memory[temp0:temp0 + 0x20] = (var2 & 0xffffffff) << 0xe0;
        var var3 = temp0 + 0x04;
        var var4 = 0x00;
        var var5 = memory[0x40:0x60];
        var var6 = var3 - var5;
        var var7 = var5;
        var var8 = 0x00;
        var var9 = var1;
        var var10 = !address(var9).code.length;
    
        if (var10) { revert(memory[0x00:0x00]); }
    
        var temp1;
        temp1, memory[var5:var5 + var4] = address(var9).call.gas(msg.gas).value(var8)(memory[var7:var7 + var6]);
    
        if (!temp1) { return; }
        else { return; }
    }
    
    function func_14FD() {
        var var0 = 0x1505;
        func_1BE1();
        var temp0 = memory[0x00:0x20];
        memory[0x00:0x20] = code[0x2b49:0x2b69];
        var temp1 = memory[0x00:0x20];
        memory[0x00:0x20] = temp0;
        storage[temp1] = 0x02;
    }
    
    function func_173F(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
        var var1 = storage[0x11];
    
        if (!(var0 - (arg0 & (0x01 << 0xa0) - 0x01))) { return ~0x00; }
    
        var var2 = 0x989680;
        var var3 = 0x00;
    
        if (arg1) {
            var var4 = 0x17cb;
            var var5 = 0x17b7;
            var var6 = var2;
            var var7 = 0x01 << 0x60;
            var var8 = arg0 & (0x01 << 0xa0) - 0x01;
        
        label_1F45:
            var var9 = 0x00;
            var var10 = var9;
            var var11 = 0x00;
            var var12 = 0x1f52;
            var var13 = var6;
            var var14 = var7;
            var var15 = 0x00;
            var var16 = var15;
            var var17 = ~0x00;
            var var18 = var14;
            var var19 = var13;
            // Unhandled termination
        } else {
            var4 = 0x1797;
            var5 = 0x1783;
            var6 = var2;
            var7 = arg0 & (0x01 << 0xa0) - 0x01;
            var8 = 0x01 << 0x60;
            goto label_1F45;
        }
    }
    
    function func_181A(var arg0, var arg1, var arg2) {
        if (arg0 & (0x01 << 0xa0) - 0x01) {
            memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
            memory[0x20:0x40] = 0x00;
            var var0 = storage[keccak256(memory[0x00:0x40])];
        
            if (var0 >= arg2) {
                memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
                memory[0x20:0x40] = 0x00;
                storage[keccak256(memory[0x00:0x40])] = var0 - arg2;
            
                if (arg1 & (0x01 << 0xa0) - 0x01) {
                label_18D0:
                    var temp0 = arg1;
                    memory[0x00:0x20] = temp0 & (0x01 << 0xa0) - 0x01;
                    memory[0x20:0x40] = 0x00;
                    var temp1 = keccak256(memory[0x00:0x40]);
                    var temp2 = arg2;
                    storage[temp1] = temp2 + storage[temp1];
                    var0 = temp0 & (0x01 << 0xa0) - 0x01;
                    var var1 = arg0 & (0x01 << 0xa0) - 0x01;
                    var var2 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
                    var temp3 = memory[0x40:0x60];
                    memory[temp3:temp3 + 0x20] = temp2;
                    var var3 = temp3 + 0x20;
                
                label_1933:
                    var temp4 = memory[0x40:0x60];
                    log(memory[temp4:temp4 + var3 - temp4], [stack[-2], stack[-3], stack[-4]]);
                    return;
                } else {
                label_18C3:
                    storage[0x02] = storage[0x02] - arg2;
                    var0 = arg1 & (0x01 << 0xa0) - 0x01;
                    var1 = arg0 & (0x01 << 0xa0) - 0x01;
                    var2 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
                    var temp5 = memory[0x40:0x60];
                    memory[temp5:temp5 + 0x20] = arg2;
                    var3 = temp5 + 0x20;
                    goto label_1933;
                }
            } else {
                var temp6 = memory[0x40:0x60];
                memory[temp6:temp6 + 0x20] = 0x391434e3 << 0xe2;
                memory[temp6 + 0x04:temp6 + 0x04 + 0x20] = arg0 & (0x01 << 0xa0) - 0x01;
                memory[temp6 + 0x24:temp6 + 0x24 + 0x20] = var0;
                memory[temp6 + 0x44:temp6 + 0x44 + 0x20] = arg2;
                var1 = temp6 + 0x64;
                var temp7 = memory[0x40:0x60];
                revert(memory[temp7:temp7 + var1 - temp7]);
            }
        } else {
            var0 = arg2;
            var1 = 0x02;
            var2 = 0x00;
            var3 = 0x1839;
            var var4 = var0;
            var var5 = storage[var1];
            var3 = func_2687(var4, var5);
            storage[var1] = var3;
        
            if (arg1 & (0x01 << 0xa0) - 0x01) { goto label_18D0; }
            else { goto label_18C3; }
        }
    }
    
    function func_1940(var arg0, var arg1, var arg2, var arg3) {
        if (!(arg0 & (0x01 << 0xa0) - 0x01)) {
            var temp6 = memory[0x40:0x60];
            memory[temp6:temp6 + 0x20] = 0xe602df05 << 0xe0;
            memory[temp6 + 0x04:temp6 + 0x04 + 0x20] = 0x00;
            var0 = temp6 + 0x24;
            goto label_1425;
        } else if (arg1 & (0x01 << 0xa0) - 0x01) {
            var temp0 = (0x01 << 0xa0) - 0x01;
            memory[0x00:0x20] = arg0 & temp0;
            memory[0x20:0x40] = 0x01;
            var temp1 = keccak256(memory[0x00:0x40]);
            memory[0x00:0x20] = arg1 & temp0;
            memory[0x20:0x40] = temp1;
            storage[keccak256(memory[0x00:0x40])] = arg2;
        
            if (!arg3) { return; }
        
            var var0 = arg1 & (0x01 << 0xa0) - 0x01;
            var var1 = arg0 & (0x01 << 0xa0) - 0x01;
            var var2 = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
            var temp2 = memory[0x40:0x60];
            memory[temp2:temp2 + 0x20] = arg2;
            var var3 = temp2 + 0x20;
            var temp3 = memory[0x40:0x60];
            log(memory[temp3:temp3 + var3 - temp3], [stack[-2], stack[-3], stack[-4]]);
            return;
        } else {
            var temp4 = memory[0x40:0x60];
            memory[temp4:temp4 + 0x20] = 0x4a1406b1 << 0xe1;
            memory[temp4 + 0x04:temp4 + 0x04 + 0x20] = 0x00;
            var0 = temp4 + 0x24;
        
        label_1425:
            var temp5 = memory[0x40:0x60];
            revert(memory[temp5:temp5 + var0 - temp5]);
        }
    }
    
    function func_1A12(var arg0, var arg1, var arg2) {
        memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
        memory[0x20:0x40] = 0x12;
        var var0 = storage[keccak256(memory[0x00:0x40])] & 0xff;
    
        if (!var0) {
            memory[0x00:0x20] = arg1 & (0x01 << 0xa0) - 0x01;
            memory[0x20:0x40] = 0x12;
        
            if (!(storage[keccak256(memory[0x00:0x40])] & 0xff)) { goto label_1A64; }
            else { goto label_1A55; }
        } else if (!var0) {
        label_1A64:
        
            if (storage[0x0e] / (0x01 << 0xa8) & 0xff) {
                var0 = 0x00;
                var var1 = var0;
                var var2 = 0x1ad1;
                var var3;
                var2, var3 = currentTaxes();
                var0 = var2;
                var1 = var3;
                var temp0 = (0x01 << 0xa0) - 0x01;
            
                if ((arg0 & temp0) - (temp0 & storage[0x0e])) {
                    var temp1 = (0x01 << 0xa0) - 0x01;
                
                    if ((arg1 & temp1) - (temp1 & storage[0x0e])) {
                        var2 = 0x1bd4;
                        var3 = arg0;
                        var var4 = arg1;
                        var var5 = arg2;
                        func_181A(var3, var4, var5);
                    
                    label_1BD4:
                    
                    label_1BD7:
                        var0 = 0x13bc;
                        var1 = arg0;
                        var2 = arg1;
                        func_1FF5(var1, var2);
                        return;
                    } else {
                        var2 = 0x1b66;
                        var3 = arg0;
                        var4 = arg1;
                        var5 = arg2;
                        func_181A(var3, var4, var5);
                        var2 = 0x00;
                        var3 = 0x2710;
                        var4 = 0x1b78;
                        var5 = var1 & 0xffff;
                        var var6 = arg2;
                        var4 = func_2A7C(var5, var6);
                        var temp2 = var3;
                        var3 = 0x1b82;
                        var temp3 = var4;
                        var4 = temp2;
                        var5 = temp3;
                        var3 = func_2A03(var4, var5);
                        var2 = var3;
                        var3 = 0x00;
                        memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
                        memory[0x20:0x40] = 0x00;
                        var4 = storage[keccak256(memory[0x00:0x40])];
                        var3 = var4;
                    
                        if (var2 > var3) {
                            var2 = var3;
                        
                            if (!var2) { goto label_1BC2; }
                            else { goto label_1BB8; }
                        } else if (!var2) {
                        label_1BC2:
                            goto label_1BD4;
                        } else {
                        label_1BB8:
                            var4 = 0x1bc2;
                            var5 = arg0;
                            var6 = address(this);
                            var var7 = var2;
                            func_181A(var5, var6, var7);
                            goto label_1BC2;
                        }
                    }
                } else {
                    var2 = 0x00;
                    var3 = 0x2710;
                    var4 = 0x1afe;
                    var5 = var0 & 0xffff;
                    var6 = arg2;
                    var4 = func_2A7C(var5, var6);
                    var temp4 = var3;
                    var3 = 0x1b08;
                    var temp5 = var4;
                    var4 = temp4;
                    var5 = temp5;
                    var3 = func_2A03(var4, var5);
                    var2 = var3;
                
                    if (!var2) {
                        var3 = 0x1b3f;
                        var4 = arg0;
                        var5 = arg1;
                        var6 = arg2;
                        func_181A(var4, var5, var6);
                    
                    label_1B3F:
                        goto label_1BD4;
                    } else {
                        var3 = 0x1b1b;
                        var4 = arg0;
                        var5 = address(this);
                        var6 = var2;
                        func_181A(var4, var5, var6);
                        var3 = 0x1b2f;
                        var4 = arg0;
                        var5 = arg1;
                        var6 = 0x1b2a;
                        var7 = var2;
                        var var8 = arg2;
                        var6 = func_2A93(var7, var8);
                        func_1B2A(var4, var5, var6);
                        goto label_1B3F;
                    }
                }
            } else {
                var temp6 = (0x01 << 0xa0) - 0x01;
                var0 = storage[0x0e] & temp6 == temp6 & arg0;
            
                if (!var0) {
                    var temp9 = (0x01 << 0xa0) - 0x01;
                
                    if (storage[0x0e] & temp9 != temp9 & arg1) { goto label_1ABC; }
                    else { goto label_1AA4; }
                } else if (!var0) {
                label_1ABC:
                    var0 = 0x1a5f;
                    var1 = arg0;
                    var2 = arg1;
                    var3 = arg2;
                    func_181A(var1, var2, var3);
                
                label_1A5F:
                    goto label_1BD7;
                } else {
                label_1AA4:
                    var temp7 = memory[0x40:0x60];
                    memory[temp7:temp7 + 0x20] = 0x6b954c37 << 0xe1;
                    var temp8 = memory[0x40:0x60];
                    revert(memory[temp8:temp8 + (temp7 + 0x04) - temp8]);
                }
            }
        } else {
        label_1A55:
            var0 = 0x1a5f;
            var1 = arg0;
            var2 = arg1;
            var3 = arg2;
            func_181A(var1, var2, var3);
            goto label_1A5F;
        }
    }
    
    function func_1B2A(var arg0, var arg1, var arg2) {
        func_181A(arg0, arg1, arg2);
        // Error: Could not resolve method call return address!
    }
    
    function func_1BE1() {
        var var0 = 0x1bfa;
        var var1 = 0x00;
        var var2 = 0x02;
        var temp0 = memory[0x00:0x20];
        memory[0x00:0x20] = code[0x2b49:0x2b69];
        var var3 = memory[0x00:0x20];
        memory[0x00:0x20] = temp0;
        var0 = func_2095(var1, var2, var3);
    
        if (!var0) { return; }
    
        var temp1 = memory[0x40:0x60];
        memory[temp1:temp1 + 0x20] = 0x3ee5aeb5 << 0xe0;
        var temp2 = memory[0x40:0x60];
        revert(memory[temp2:temp2 + (temp1 + 0x04) - temp2]);
    }
    
    function func_1FF5(var arg0, var arg1) {
        var var0 = storage[0x0d] & (0x01 << 0xa0) - 0x01;
    
        if (!var0) { return; }
    
        memory[0x00:0x20] = arg0 & (0x01 << 0xa0) - 0x01;
        memory[0x20:0x40] = 0x12;
        var var1 = !(storage[keccak256(memory[0x00:0x40])] & 0xff);
    
        if (var1) {
            var temp1 = (0x01 << 0xa0) - 0x01;
        
            if (storage[0x0e] & temp1 == temp1 & arg0) { goto label_2050; }
            else { goto label_2047; }
        } else if (!var1) {
        label_2050:
            memory[0x00:0x20] = arg1 & (0x01 << 0xa0) - 0x01;
            memory[0x20:0x40] = 0x12;
            var1 = !(storage[keccak256(memory[0x00:0x40])] & 0xff);
        
            if (var1) {
                var temp0 = (0x01 << 0xa0) - 0x01;
            
                if (storage[0x0e] & temp0 == temp0 & arg1) { goto label_13BC; }
                else { goto label_208C; }
            } else if (!var1) {
            label_13BC:
                return;
            } else {
            label_208C:
                var1 = 0x13bc;
                var var2 = var0;
                var var3 = arg1;
                func_21CF(var2, var3);
                goto label_13BC;
            }
        } else {
        label_2047:
            var1 = 0x2050;
            var2 = var0;
            var3 = arg0;
            func_21CF(var2, var3);
            goto label_2050;
        }
    }
    
    function func_2095(var arg0, var arg1, var arg2) returns (var r0) { return storage[arg2] == arg1; }
    
    function func_209C(var arg0, var arg1, var arg2) returns (var r0) {
        var var0 = 0x00;
        var var1 = !(arg1 & (0x01 << 0x80) - 0x01);
    
        if (var1) {
            if (!var1) {
            label_20C6:
                var1 = 0x00;
                var var2 = 0x2710;
                var var3 = 0x20df;
                var var4 = 0x01f4;
                var var5 = arg1 & (0x01 << 0x80) - 0x01;
                var3 = func_2A7C(var4, var5);
                var temp0 = var2;
                var2 = 0x20e9;
                var temp1 = var3;
                var3 = temp0;
                var4 = temp1;
                var2 = func_2A03(var3, var4);
                var1 = var2;
            
                if (arg2) {
                    var2 = 0x2125;
                    var3 = var1;
                    var4 = 0x01 << 0x60;
                    var5 = arg0 & (0x01 << 0xa0) - 0x01;
                
                label_1F45:
                    var var6 = 0x00;
                    var var7 = var6;
                    var var8 = 0x00;
                    var var9 = 0x1f52;
                    var var10 = var3;
                    var var11 = var4;
                    var var12 = 0x00;
                    var var13 = var12;
                    var var14 = ~0x00;
                    var var15 = var11;
                    var var16 = var10;
                    // Unhandled termination
                } else {
                    var2 = 0x2108;
                    var3 = var1;
                    var4 = arg0 & (0x01 << 0xa0) - 0x01;
                    var5 = 0x01 << 0x60;
                    goto label_1F45;
                }
            } else {
            label_20C0:
                return 0x00;
            }
        } else if (arg0 & (0x01 << 0xa0) - 0x01) { goto label_20C6; }
        else { goto label_20C0; }
    }
    
    function func_21CF(var arg0, var arg1) {
        var var0 = arg0 & (0x01 << 0xa0) - 0x01;
        var var1 = 0x14b6ca96;
        var var2 = 0x030d40;
        var var3 = arg1;
        memory[0x00:0x20] = var3 & (0x01 << 0xa0) - 0x01;
        memory[0x20:0x40] = 0x00;
        var var4 = storage[keccak256(memory[0x00:0x40])];
        var temp0 = memory[0x40:0x60];
        memory[temp0:temp0 + 0x20] = (var1 << 0xe0) & ~((0x01 << 0xe0) - 0x01);
        memory[temp0 + 0x04:temp0 + 0x04 + 0x20] = var3 & (0x01 << 0xa0) - 0x01;
        memory[temp0 + 0x24:temp0 + 0x24 + 0x20] = var4;
        var3 = temp0 + 0x44;
        var4 = 0x00;
        var var5 = memory[0x40:0x60];
        var var6 = var3 - var5;
        var var7 = var5;
        var var8 = 0x00;
        var var9 = var0;
        var var10 = !address(var9).code.length;
    
        if (var10) { revert(memory[0x00:0x00]); }
    
        var temp1;
        temp1, memory[var5:var5 + var4] = address(var9).call.gas(var2).value(var8)(memory[var7:var7 + var6]);
    
        if (!temp1) {
            if (var0) {
            label_10D5:
                return;
            } else {
            label_225B:
                log(memory[memory[0x40:0x60]:memory[0x40:0x60] + 0x00], [0x0eae776f8a8204bfc7ccedc05d6c2409be02ee97f547a33f4f129bc85384ea31, stack[-1] & (0x01 << 0xa0) - 0x01]);
                return;
            }
        } else if (0x01) { goto label_10D5; }
        else { goto label_225B; }
    }
    
    function func_2291(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
        var var1 = 0x20;
        var temp0 = arg1;
        memory[temp0:temp0 + 0x20] = var1;
        var temp1 = memory[arg0:arg0 + 0x20];
        var var2 = temp1;
        memory[temp0 + 0x20:temp0 + 0x20 + 0x20] = var2;
        var var3 = 0x00;
    
        if (var3 >= var2) {
        label_22BD:
            var temp2 = var2;
            var temp3 = arg1;
            memory[temp3 + temp2 + 0x40:temp3 + temp2 + 0x40 + 0x20] = 0x00;
            return temp3 + (temp2 + 0x1f & ~0x1f) + 0x40;
        } else {
        label_22AA:
            var temp4 = var3;
            var temp5 = var1;
            memory[temp4 + arg1 + 0x40:temp4 + arg1 + 0x40 + 0x20] = memory[temp5 + temp4 + arg0:temp5 + temp4 + arg0 + 0x20];
            var3 = temp5 + temp4;
        
            if (var3 >= var2) { goto label_22BD; }
            else { goto label_22AA; }
        }
    }
    
    function func_22DD(var arg0) {
        var temp0 = arg0;
    
        if (temp0 == temp0 & (0x01 << 0xa0) - 0x01) { return; }
        else { revert(memory[0x00:0x00]); }
    }
    
    function transfer(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
    
        if (arg0 - arg1 i< 0x40) { revert(memory[0x00:0x00]); }
    
        var var2 = msg.data[arg1:arg1 + 0x20];
        var var3 = 0x230d;
        var var4 = var2;
        func_22DD(var4);
        r0 = var2;
        arg0 = msg.data[arg1 + 0x20:arg1 + 0x20 + 0x20];
        return r0, arg0;
    }
    
    function func_231B(var arg0, var arg1) returns (var r0, var arg0, var arg1) {
        var var0 = 0x00;
        var var1 = var0;
        var var2 = 0x00;
    
        if (arg0 - arg1 i< 0x60) { revert(memory[0x00:0x00]); }
    
        var var3 = msg.data[arg1:arg1 + 0x20];
        var var4 = 0x2338;
        var var5 = var3;
        func_22DD(var5);
        var0 = var3;
        var3 = msg.data[arg1 + 0x20:arg1 + 0x20 + 0x20];
        var4 = 0x2348;
        var5 = var3;
        func_22DD(var5);
        r0 = var0;
        arg0 = var3;
        arg1 = msg.data[arg1 + 0x40:arg1 + 0x40 + 0x20];
        return r0, arg0, arg1;
    }
    
    function func_2359(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var var1 = msg.data[arg1:arg1 + 0x20];
        var var2 = 0x07b5;
        var var3 = var1;
        func_22DD(var3);
        return var1;
    }
    
    function func_2374(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
    
        if (arg0 - arg1 i< 0x40) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1;
        r0 = msg.data[temp0:temp0 + 0x20];
        arg0 = msg.data[temp0 + 0x20:temp0 + 0x20 + 0x20];
        return r0, arg0;
    }
    
    function config(var arg0, var arg1) returns (var r0) {
        var temp0 = arg1;
        var var0 = temp0 + 0x0100;
        var temp1 = arg0;
        memory[temp0:temp0 + 0x20] = memory[temp1:temp1 + 0x20] & 0xffff;
        memory[temp0 + 0x20:temp0 + 0x20 + 0x20] = memory[temp1 + 0x20:temp1 + 0x20 + 0x20] & 0xffff;
        memory[temp0 + 0x40:temp0 + 0x40 + 0x20] = memory[temp1 + 0x40:temp1 + 0x40 + 0x20] & 0xffff;
        memory[temp0 + 0x60:temp0 + 0x60 + 0x20] = memory[temp1 + 0x60:temp1 + 0x60 + 0x20] & 0xffff;
        memory[temp0 + 0x80:temp0 + 0x80 + 0x20] = memory[temp1 + 0x80:temp1 + 0x80 + 0x20] & 0xffff;
        memory[temp0 + 0xa0:temp0 + 0xa0 + 0x20] = memory[temp1 + 0xa0:temp1 + 0xa0 + 0x20] & (0x01 << 0xa0) - 0x01;
        var var1 = memory[temp1 + 0xc0:temp1 + 0xc0 + 0x20];
        memory[temp0 + 0xc0:temp0 + 0xc0 + 0x20] = var1 & 0xffffffff;
        var1 = memory[arg0 + 0xe0:arg0 + 0xe0 + 0x20];
        memory[arg1 + 0xe0:arg1 + 0xe0 + 0x20] = var1 & (0x01 << 0x60) - 0x01;
        return var0;
    }
    
    function func_2421(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var var1 = msg.data[arg1:arg1 + 0x20];
    
        if (var1 > 0xffffffffffffffff) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1 + var1;
        var1 = temp0;
    
        if (arg0 - var1 i>= 0x0240) { return var1; }
        else { revert(memory[0x00:0x00]); }
    }
    
    function func_2459(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
    
        if (arg0 - arg1 i< 0x40) { revert(memory[0x00:0x00]); }
    
        var var2 = msg.data[arg1:arg1 + 0x20];
        var var3 = 0x2475;
        var var4 = var2;
        func_22DD(var4);
        var0 = var2;
        var2 = msg.data[arg1 + 0x20:arg1 + 0x20 + 0x20];
        var3 = 0x2485;
        var4 = var2;
        func_22DD(var4);
        arg0 = var2;
        r0 = var0;
        return r0, arg0;
    }
    
    function func_2490(var arg0) {
        var temp0 = arg0;
    
        if (temp0 == temp0 & 0xffff) { return; }
        else { revert(memory[0x00:0x00]); }
    }
    
    function func_249F(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
    
        if (arg0 - arg1 i< 0x40) { revert(memory[0x00:0x00]); }
    
        var var2 = msg.data[arg1:arg1 + 0x20];
        var var3 = 0x24bb;
        var var4 = var2;
        func_2490(var4);
        var0 = var2;
        var2 = msg.data[arg1 + 0x20:arg1 + 0x20 + 0x20];
        var3 = 0x2485;
        var4 = var2;
        func_2490(var4);
        arg0 = var2;
        r0 = var0;
        return r0, arg0;
    }
    
    function func_24CB(var arg0, var arg1) returns (var r0, var arg0, var arg1, var r3) {
        r3 = 0x00;
        var var1 = r3;
        var var2 = 0x00;
        var var3 = var2;
    
        if (arg0 - arg1 i< 0x60) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1;
        r3 = msg.data[temp0:temp0 + 0x20];
        var1 = msg.data[temp0 + 0x20:temp0 + 0x20 + 0x20];
        var var4 = msg.data[temp0 + 0x40:temp0 + 0x40 + 0x20];
        var var5 = 0xffffffffffffffff;
    
        if (var4 > var5) { revert(memory[0x00:0x00]); }
    
        var temp1 = arg1 + var4;
        var4 = temp1;
    
        if (var4 + 0x1f i>= arg0) { revert(memory[0x00:0x00]); }
    
        var var6 = msg.data[var4:var4 + 0x20];
    
        if (var6 > var5) { revert(memory[0x00:0x00]); }
    
        if (var4 + var6 + 0x20 > arg0) { revert(memory[0x00:0x00]); }
    
        var temp2 = r3;
        r3 = var6;
        r0 = temp2;
        arg0 = var1;
        arg1 = var4 + 0x20;
        return r0, arg0, arg1, r3;
    }
    
    function func_2544(var arg0) returns (var r0) {
        var temp0 = arg0;
        var var0 = temp0 >> 0x01;
        var var1 = temp0 & 0x01;
    
        if (!var1) {
            var temp1 = var0 & 0x7f;
            var0 = temp1;
        
            if (var1 - (var0 < 0x20)) { goto label_2576; }
            else { goto label_2563; }
        } else if (var1 - (var0 < 0x20)) {
        label_2576:
            return var0;
        } else {
        label_2563:
            memory[0x00:0x20] = 0x4e487b71 << 0xe0;
            memory[0x04:0x24] = 0x22;
            revert(memory[0x00:0x24]);
        }
    }
    
    function func_2597(var arg0, var arg1) returns (var r0, var arg0, var arg1, var r3, var r4, var r5, var r6) {
        r3 = 0x00;
        r4 = r3;
        r5 = 0x00;
        r6 = r5;
        var var4 = 0x00;
        var var5 = var4;
        var var6 = 0x00;
    
        if (arg0 - arg1 i< 0xe0) { revert(memory[0x00:0x00]); }
    
        var var7 = memory[arg1:arg1 + 0x20];
        var var8 = 0x25b8;
        var var9 = var7;
        func_22DD(var9);
        r3 = var7;
        var temp0 = memory[arg1 + 0x20:arg1 + 0x20 + 0x20];
        var7 = temp0;
    
        if (var7 != signextend(0x02, var7)) { revert(memory[0x00:0x00]); }
    
        var temp1 = var7;
        var7 = memory[arg1 + 0x40:arg1 + 0x40 + 0x20];
        r4 = temp1;
        var8 = 0x25e0;
        var9 = var7;
        func_2490(var9);
        var temp2 = var7;
        var7 = memory[arg1 + 0x60:arg1 + 0x60 + 0x20];
        r5 = temp2;
        var8 = 0x25f1;
        var9 = var7;
        func_2490(var9);
        var temp3 = var7;
        var7 = memory[arg1 + 0x80:arg1 + 0x80 + 0x20];
        r6 = temp3;
        var8 = 0x2602;
        var9 = var7;
        func_2490(var9);
        var temp4 = memory[arg1 + 0xa0:arg1 + 0xa0 + 0x20];
        var temp5 = var7;
        var7 = temp4;
        var4 = temp5;
    
        if (var7 != var7 & 0xff) { revert(memory[0x00:0x00]); }
    
        var temp6 = memory[arg1 + 0xc0:arg1 + 0xc0 + 0x20];
        var temp7 = var7;
        var7 = temp6;
        var5 = temp7;
    
        if (var7 != !!var7) { revert(memory[0x00:0x00]); }
    
        var temp8 = r6;
        r6 = var7;
        var temp9 = r3;
        r3 = temp8;
        r0 = temp9;
        var temp10 = r4;
        r4 = var4;
        arg0 = temp10;
        var temp11 = r5;
        r5 = var5;
        arg1 = temp11;
        return r0, arg0, arg1, r3, r4, r5, r6;
    }
    
    function func_263D(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var var1 = msg.data[arg1:arg1 + 0x20];
        var var2 = 0x07b5;
        var var3 = var1;
        func_2490(var3);
        return var1;
    }
    
    function func_266C(var arg0, var arg1) returns (var r0) {
        var var0 = (arg0 & 0xffff) + (arg1 & 0xffff);
        var var1 = 0xffff;
    
        if (var0 <= var1) { return var0; }
    
        var var2 = 0x241a;
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x11;
        revert(memory[0x00:0x24]);
    }
    
    function func_2687(var arg0, var arg1) returns (var r0) {
        var temp0 = arg1;
        var var0 = arg0 + temp0;
    
        if (temp0 <= var0) { return var0; }
    
        var var1 = 0x0791;
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x11;
        revert(memory[0x00:0x24]);
    }
    
    function func_269A(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
        var var2 = msg.data[arg0:arg0 + 0x20];
    
        if (var2 i>= msg.data.length - arg1 + ~0x1e) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1 + var2;
        var2 = temp0;
        var1 = msg.data[var2:var2 + 0x20];
    
        if (var1 > 0xffffffffffffffff) { revert(memory[0x00:0x00]); }
    
        var0 = var2 + 0x20;
    
        if (var0 i> msg.data.length - var1) { revert(memory[0x00:0x00]); }
    
        arg0 = var1;
        r0 = var0;
        return r0, arg0;
    }
    
    function func_273C(var arg0, var arg1, var arg2) {
        if (arg0 <= 0xffffffffffffffff) {
            var var0 = 0x2768;
            var var1 = arg0;
            var var2 = 0x2762;
            var var3 = storage[arg2];
            var2 = func_2544(var3);
            func_2762(arg2, var1, var2);
            var0 = 0x00;
            var1 = arg0 > 0x1f;
        
            if (var1 == 0x01) {
                memory[0x00:0x20] = arg2;
                var3 = keccak256(memory[0x00:0x20]);
                var2 = arg0 & ~0x1f;
                var var4 = 0x00;
            
                if (var4 >= var2) {
                label_27C8:
                
                    if (var2 >= arg0) {
                        storage[arg2] = (arg0 << 0x01) + 0x01;
                        return;
                    } else {
                        var temp0 = arg0;
                        storage[var3] = msg.data[arg1 + var0:arg1 + var0 + 0x20] & ~(~0x00 >> ((temp0 << 0x03) & 0xf8));
                        storage[arg2] = (temp0 << 0x01) + 0x01;
                        return;
                    }
                } else {
                label_27B1:
                    var temp1 = var0;
                    var temp2 = var3;
                    storage[temp2] = msg.data[temp1 + arg1:temp1 + arg1 + 0x20];
                    var0 = temp1 + 0x20;
                    var3 = temp2 + 0x01;
                    var4 = var4 + 0x20;
                
                    if (var4 >= var2) { goto label_27C8; }
                    else { goto label_27B1; }
                }
            } else {
                var2 = 0x00;
            
                if (!arg0) {
                    var temp3 = arg0;
                    storage[arg2] = (temp3 << 0x01) | (~(~0x00 >> (temp3 << 0x03)) & var2);
                
                label_09CF:
                    return;
                } else {
                    var temp4 = arg0;
                    storage[arg2] = (temp4 << 0x01) | (~(~0x00 >> (temp4 << 0x03)) & msg.data[var0 + arg1:var0 + arg1 + 0x20]);
                    goto label_09CF;
                }
            }
        } else {
            var0 = 0x2754;
            memory[0x00:0x20] = 0x4e487b71 << 0xe0;
            memory[0x04:0x24] = 0x41;
            revert(memory[0x00:0x24]);
        }
    }
    
    function func_2762(var arg0, var arg1, var arg2) {
        var var0 = arg0;
    
        if (arg2 <= 0x1f) { return; }
    
        memory[0x00:0x20] = var0;
        var var1 = keccak256(memory[0x00:0x20]);
        var temp0 = arg1;
        var var2 = var1 + (temp0 + 0x1f >> 0x05);
    
        if (temp0 >= 0x20) {
            var temp1 = var1 + (arg2 + 0x1f >> 0x05);
            var1 = temp1;
        
            if (var2 >= var1) {
            label_09CF:
                return;
            } else {
            label_2732:
                var temp2 = var2;
                storage[temp2] = 0x00;
                var2 = temp2 + 0x01;
            
                if (var2 >= var1) { goto label_09CF; }
                else { goto label_2732; }
            }
        } else {
            var temp3 = var1;
            var2 = temp3;
            var1 = var2 + (arg2 + 0x1f >> 0x05);
        
            if (var2 >= var1) { goto label_09CF; }
            else { goto label_2732; }
        }
    }
    
    function func_2A03(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0) { return arg1 / arg0; }
    
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x12;
        revert(memory[0x00:0x24]);
    }
    
    function func_2A7C(var arg0, var arg1) returns (var r0) {
        var temp0 = arg1;
        var temp1 = arg0;
        var var0 = temp1 * temp0;
    
        if ((temp1 == var0 / temp0) | !temp0) { return var0; }
    
        var var1 = 0x0791;
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x11;
        revert(memory[0x00:0x24]);
    }
    
    function func_2A93(var arg0, var arg1) returns (var r0) {
        var temp0 = arg1;
        var var0 = temp0 - arg0;
    
        if (var0 <= temp0) { return var0; }
    
        var var1 = 0x0791;
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x11;
        revert(memory[0x00:0x24]);
    }
    
    function func_2AA6(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var temp0 = memory[arg1:arg1 + 0x20];
        var var1 = temp0;
    
        if (var1 == var1 & (0x01 << 0x80) - 0x01) { return var1; }
        else { revert(memory[0x00:0x00]); }
    }
}

