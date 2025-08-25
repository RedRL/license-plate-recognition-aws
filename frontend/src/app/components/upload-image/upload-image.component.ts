import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { FormsModule } from '@angular/forms';
import { UploadImageService } from '../../services/upload-image-service';

@Component({
  selector: 'app-upload-image',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatButtonModule,
    MatIconModule,
    MatCardModule,
    MatInputModule,
    MatFormFieldModule,
    MatProgressBarModule
  ],
  templateUrl: './upload-image.component.html',
  styleUrl: './upload-image.component.scss'
})
export class UploadImageComponent {
  selectedFile: File | null = null;
  uploading = false;
  result: { plate: string; make: string | null; model: string | null; color: string | null } | null = null;
  errorMessage: string | null = null;

  constructor(private uploadImageService: UploadImageService) { }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input?.files?.length) {
      this.selectedFile = input.files[0];
    }
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
  }

  onDrop(event: DragEvent): void {
    event.preventDefault();
    if (event.dataTransfer?.files?.length) {
      this.selectedFile = event.dataTransfer.files[0];
    }
  }

  onUpload(): void {
    if (this.selectedFile) {
      this.uploading = true;
      this.result = null;
      this.errorMessage = null;
      this.uploadImageService.uploadImage(this.selectedFile).subscribe({
        next: (res) => {
          console.log('Upload success response:', res);
          this.uploading = false;
          this.result = {
            plate: res?.plate ?? 'UNKNOWN',
            make: res?.make ?? null,
            model: res?.model ?? null,
            color: res?.color ?? null
          };
        },
        error: (err) => {
          console.error('Upload error response:', err);
          this.uploading = false;
          this.errorMessage = err?.error?.error ?? 'Upload or recognition failed.';
        }
      });
    }
  }
}
