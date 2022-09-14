function setcell_low(handle,event,obj,hpaint,classif,him,hp,txt )

prev=findobj(hpaint,'Type','Line');

if prev.UserData==txt
    disp('The selected cell index is identical to the original cell index');
    return
end

if numel(txt) && numel(prev)

    prev=prev.UserData;
    pixelchannel=obj.findChannelID(classif.strid);
    pixcha=find(obj.channelid==pixelchannel);


    if numel(pixcha)

        % check if cell was present already ask if it should be replaced
        tt= obj.image(:,:,pixcha,obj.display.frame:end);

        pixcellex= tt==txt;

        if numel(find(pixcellex))
            answer = questdlg('The cell number you chose is already present. What should be done with that existing cell ? :', ...
                'Cell ID processing menu', ...
                'Change the cell number to preserve that cell','Only assign this number in frames where that cell is not present','Cancel','Change the cell number to preserve that cell');
            % Handle response
            switch answer
                case 'Change the cell number to preserve that cell'
                    dessert = 1;
                case 'Only assign this number in frames where that cell is not present'
                    dessert = 2;
                case 'Cancel'
                    dessert = 0;
            end

            if dessert==0
                disp('User canceled selection')
                return;
            end

        else
              dessert=0;
        end

             if dessert==0
                 pixcell= obj.image(:,:,pixcha,obj.display.frame:end)==prev; % pixels to be replace
                imtmp= obj.image(:,:,pixcha,obj.display.frame:end);
                imtmp(pixcell)= txt;
             end

            if dessert==1 % must renumber the target cell before processing further
                imtmp= obj.image(:,:,pixcha,:);
                me=max(imtmp(:));
                imtmp= obj.image(:,:,pixcha,obj.display.frame:end);
                imtmp(pixcellex)=me+1;

                pixcell= obj.image(:,:,pixcha,obj.display.frame:end)==prev; % pixels to be replace
            %    imtmp= obj.image(:,:,pixcha,obj.display.frame:end);
                 imtmp(pixcell)= txt;
            end

            if dessert==2 % must identify the missing frames

                imtmp= obj.image(:,:,pixcha,:);

                for i=obj.display.frame:size(obj.image,4)

                    pixmiss= obj.image(:,:,pixcha,i)==txt; %%% HERE

                    if numel(find(pixmiss))==0
                          imtmp2=imtmp(:,:,:,i);

                        pixcell= imtmp2==prev;
                      
                        imtmp2(pixcell)=txt;
                        imtmp(:,:,:,i)=imtmp2;
                    end
                end

                imtmp=imtmp(:,:,:,obj.display.frame:end);
            end


            obj.image(:,:,pixcha,obj.display.frame:end)=imtmp;

            updatedisplay(obj,him,hp,classif)
    end

end
end